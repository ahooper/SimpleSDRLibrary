//
//  SDRplay.swift
//  SimpleSDR
//
//  Project / Signing & Capabilities / App Sandbox / USB
//
//  https://www.sdrplay.com/docs/SDRplay_SDR_API_Specification.pdf
//
//  First use after connecting device on USB will not find any device, until the
//  mir_sdr library completes updating the firmware.
//
//  Created by Andy Hooper on 2019-10-04.
//  Copyright © 2019 Andy Hooper. All rights reserved.
//
import Crspsdrapi
import class Foundation.NSCondition
import class Foundation.Thread
import func Foundation.sleep

public class SDRplay:BufferedStage<NilSamples,ComplexSamples> {
    static let CLASS_NAME = "SDRplay"

    private static let EXPECTED_API_VERSION: Float = 2.13
    private static let MAX_DEVICES: UInt32 = 10
    private var numDevices: UInt32 = 0
    private var devices: Array<mir_sdr_DeviceT>
    private var deviceIndex: Int
    public var deviceDescription: String
    public var hwVersion: UInt8
    private static let SHORT_SCALE = 1.0/Float(1<<15)
    static let BUFFER_SIZE: Int = 1<<17
    var overflow: Int = 0 // the number of samples which could not fit
    private var outputFill = NSCondition()
    
    public init(initialDebug: Bool = false) {
        var apiVersion: Float = 0.0
        SDRplay.failIfError(mir_sdr_ApiVersion(&apiVersion), "ApiVersion");
        if apiVersion < SDRplay.EXPECTED_API_VERSION {
            fatalError(SDRplay.CLASS_NAME+" ApiVersion \(apiVersion) is not expected \(SDRplay.EXPECTED_API_VERSION)")
        }
        
        mir_sdr_DebugEnable(initialDebug ? 1 : 0)
        
        devices = Array<mir_sdr_DeviceT>(repeating: mir_sdr_DeviceT(), count: Int(SDRplay.MAX_DEVICES))
        SDRplay.failIfError(mir_sdr_GetDevices(&devices, &numDevices, SDRplay.MAX_DEVICES), "GetDevices")
        if numDevices == 0 {
            print(SDRplay.CLASS_NAME,"no devices found, delay for possible initialization in progress")
            mir_sdr_DebugEnable(1)
            Thread.sleep(forTimeInterval: 60)
print(SDRplay.CLASS_NAME,"retry mir_sdr_GetDevices")
            SDRplay.failIfError(mir_sdr_GetDevices(&devices, &numDevices, SDRplay.MAX_DEVICES), "GetDevices")
//TODO retrying GetDevices does not return
print(SDRplay.CLASS_NAME,"retry mir_sdr_GetDevices",numDevices)
        }
        if numDevices == 0 {
//            #if DEBUG
//                // https://stackoverflow.com/a/29991529
//                if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                    // non-fatal to allow unit tests to run
                    print(SDRplay.CLASS_NAME, "no devices found")
                    deviceIndex = -1
                    deviceDescription = "No device found"
                    hwVersion = 0
                    super.init(SDRplay.CLASS_NAME)
                    return
//                }
//            #endif
//            fatalError("\(SDRplay.CLASS_NAME) no devices found")
        }
        for i in 0..<Int(numDevices) {
            if true || initialDebug {
                print("  #",i,String(cString:devices[i].DevNm),
                      "serial",String(cString:devices[i].SerNo),
                      "hwVer",devices[i].hwVer,
                      Int(devices[i].devAvail) == 0 ? "unavailable" : "")
            }
        }
        
        deviceIndex = 0
        // TODO produce list of available devices and allow selection
        SDRplay.failIfError(mir_sdr_SetDeviceIdx(UInt32(deviceIndex)), "SetDeviceIdx")
        var deviceName = String(cString:devices[deviceIndex].DevNm)
        if let x = deviceName.range(of: "_VID_") {// _VID_1DF7&PID_3010_BUS_020_PORT_004
            deviceName.removeSubrange(x.lowerBound...)
        }
        let serialString = String(cString:devices[deviceIndex].SerNo)
        deviceDescription = "\(deviceName) Ser.\(serialString)"
        hwVersion = devices[deviceIndex].hwVer
        print("SDRplay","#",deviceIndex,deviceDescription,"HwV.",hwVersion)

        //TODO: options for DC offset and IQ imbalance correction enabled (default)
        SDRplay.failIfError(mir_sdr_DCoffsetIQimbalanceControl(1, 1), "DCoffsetIQimbalanceControl")

        super.init(SDRplay.CLASS_NAME)
        outputBuffer.reserveCapacity(SDRplay.BUFFER_SIZE)
        produceBuffer.reserveCapacity(SDRplay.BUFFER_SIZE)
    }
    
    deinit {
        //print(SDRplay.CLASS_NAME,"deinit")
        stopReceive()
    }
    
    static func failIfError(_ err: mir_sdr_ErrT , _ function: String,
                            file:StaticString=#file, line:UInt=#line) {
        if err == mir_sdr_Success { return }
        fatalError("\(CLASS_NAME) \(function) failed: \(errorString(err))", file:file, line:line)
    }
    
    static func errorString(_ err: mir_sdr_ErrT)->String {
        switch err {
            case mir_sdr_Success            : return "success";
            case mir_sdr_Fail               : return "generic Fail";
            case mir_sdr_InvalidParam       : return "invalid parameter";
            case mir_sdr_OutOfRange         : return "out of range";
            case mir_sdr_GainUpdateError    : return "gain update error";
            case mir_sdr_RfUpdateError      : return "RF update error";
            case mir_sdr_FsUpdateError      : return "Fs update error";
            case mir_sdr_HwError            : return "hardware error";
            case mir_sdr_AliasingError      : return "aliasing error";
            case mir_sdr_AlreadyInitialised : return "already initialized";
            case mir_sdr_NotInitialised     : return "not initialized";
            case mir_sdr_NotEnabled         : return "not enabled";
            case mir_sdr_HwVerError         : return "hardware version error";
            case mir_sdr_OutOfMemError      : return "out of memory";
            case mir_sdr_HwRemoved          : return "hardware removed";
            default                         : return "error code \(err)";
        }
    }
    
    let MHZ = 1e6
    private var tuneMHz: Double = 2.0
    public var tuneHz: Double {
        get {
            return tuneMHz * MHZ
        }
        set {
            tuneMHz = newValue / MHZ
            if streamInit {
                // gainChangeCallback can be called from mir_sdr_Reinit and modify gainRedndB, so it
                // is copied to a temporary and then back
                var temporaryGainRedndB = gainRedndB
                SDRplay.failIfError(mir_sdr_Reinit(&temporaryGainRedndB, 0.0, tuneMHz,
                                                   mir_sdr_BW_Undefined,
                                                   mir_sdr_IF_Undefined, mir_sdr_LO_Undefined,
                                                   lnaState, &gainRedndBSystem,
                                                   mir_sdr_USE_RSP_SET_GR, &samplesPerCallback,
                                                   mir_sdr_CHANGE_RF_FREQ),
                            "CHANGE_RF_FREQ");
                gainRedndB = temporaryGainRedndB
            }
        }
    }
    public var sampleHz: Double = 2e6 //TODO: configurable
    public var decimate: Int = 1
    private var bandwidthMode: mir_sdr_Bw_MHzT = mir_sdr_BW_1_536
    
    public var bandwidthHz: Double {
        get {
            switch bandwidthMode {
                case mir_sdr_BW_0_200   : return 200e3
                case mir_sdr_BW_0_300   : return 300e3
                case mir_sdr_BW_0_600   : return 600e3
                case mir_sdr_BW_1_536   : return 1536e3
                case mir_sdr_BW_5_000   : return 5000e3
                case mir_sdr_BW_6_000   : return 6000e3
                case mir_sdr_BW_7_000   : return 7000e3
                case mir_sdr_BW_8_000   : return 8000e3
                default                 : fatalError("SDRplay bandwidthMode unknown \(bandwidthMode)")
            }
        }
        set {
            let nv =
                newValue <= 200e3 ? mir_sdr_BW_0_200 :
                newValue <= 300e3 ? mir_sdr_BW_0_300 :
                newValue <= 600e3 ? mir_sdr_BW_0_600 :
                newValue <= 1536e3 ? mir_sdr_BW_1_536 :
                newValue <= 5000e3 ? mir_sdr_BW_5_000 :
                newValue <= 6000e3 ? mir_sdr_BW_6_000 :
                newValue <= 7000e3 ? mir_sdr_BW_7_000 :
                newValue <= 8000e3 ? mir_sdr_BW_8_000 : mir_sdr_BW_8_000; // maximum
            if bandwidthMode != nv {
                bandwidthMode = nv
                if streamInit {
                    // gainChangeCallback can be called from mir_sdr_Reinit and modify gainRedndB, so it
                    // is copied to a temporary and then back
                    var temporaryGainRedndB = gainRedndB
                    SDRplay.failIfError(mir_sdr_Reinit(&temporaryGainRedndB, 0.0, 0.0, bandwidthMode,
                                                mir_sdr_IF_Undefined, mir_sdr_LO_Undefined,
                                                lnaState, &gainRedndBSystem,
                                                mir_sdr_USE_RSP_SET_GR, &samplesPerCallback,
                                                mir_sdr_CHANGE_BW_TYPE),
                                "CHANGE_BW_TYPE");
                    gainRedndB = temporaryGainRedndB
                }
            }
        }
    }
    
    override public func sampleFrequency() -> Double {
        Double(sampleHz) / Double(decimate)
    }

    private var ifMode: mir_sdr_If_kHzT = mir_sdr_IF_Zero
    private var lnaState: Int32 = 0
    private var gainRedndBSystem: Int32 = 0
    private var gainRednMode: mir_sdr_SetGrModeT = mir_sdr_USE_SET_GR
    private var gainRedndB: Int32 = 40 // from SoapySDRPlay/Settings.cpp
                // refer to section 5 of http://www.sdrplay.com/docs/Mirics_SDR_API_Specification.pdf
    private var samplesPerCallback: Int32 = 0
    private var loMode: mir_sdr_LoModeT = mir_sdr_LO_Auto
    private var agcMode: mir_sdr_AgcControlT = mir_sdr_AGC_100HZ
    private var agcSetPoint: Int32 = -30
    private var amPort: Int32 = 0
    private var tunerSelect = mir_sdr_rspDuo_Tuner_1
    public var streamInit: Bool = false //TODO setter to do start/stopReceive
    var sampleCount:UInt64 = 0
    
    /// This callback is triggered when there are samples to be processed.
    /// - Parameter xi: Pointer to real data in the buffer.
    /// - Parameter xq: Pointer to the imaginary data in the buffer.
    /// - Parameter firstSampleNum: Number of first sample in buffer (used for synchronous updates). Note that this is divided in the API by the decimationFactor, to make it relative to the output sample rate. The values specified for sample number and period for synchronous updates should also be relative to the output sample rate.
    /// - Parameter grChanged: Indicates when the gain reduction has changed:
    ///                         Bit0 → Change status of 1st packet: 0=>no change, 1=> change occurred
    ///                         Bit1 → Change status of 2nd packet: 0=>no change, 1=> change occurred
    ///                         Bit2 → Change status of 3rd packet: 0=>no change, 1=> change occurred
    ///                         Bit3 → Change status of 4th packet: 0=>no change, 1=> change occurred
    /// - Parameter rfChanged: Indicates when the tuner frequency has changed (same bits as grChanged)
    /// - Parameter fsChanged: Indicates when the sample frequency has changed (same bits as grChanged)
    /// - Parameter numSamples: The number of samples in the current buffer.
    /// - Parameter reset: Indicates if a re-initialisation has occurred and that the local buffering should be reset.
    /// - Parameter hwRemoved: Indicates that the hardware has been removed (surprise removal)
    /// - Parameter cbContext: Pointer to context passed into mir_sdr_StreamInit().
    private static let streamCallback: mir_sdr_StreamCallback_t = {
                (xi:Optional<UnsafeMutablePointer<Int16>>,
                xq:Optional<UnsafeMutablePointer<Int16>>,
                firstSampleNum:UInt32,
                grChanged:Int32,
                rfChanged:Int32,
                fsChanged:Int32,
                numSamples:UInt32,
                reset:UInt32,
                hwRemoved:UInt32,
                cbContext:Optional<UnsafeMutableRawPointer>) in
        let s = Unmanaged<SDRplay>.fromOpaque(cbContext!).takeUnretainedValue()
        //print(SDRplay.CLASS_NAME,"streamCallback",numSamples)
        s.callbackTime.start()
        //let _ = s.outputBuffer.capacity // verify real & imag capacity equal
        if s.streamInit {
            if let xi = xi, let xq = xq {
                s.callbackLockTime.start()
                s.outputFill.lock()
                    s.callbackLockTime.stop()
                    //print(SDRplay.CLASS_NAME, s.outputIndex, s.outputBuffer.capacity, s.outputBuffer.count, numSamples)
                    let n = min(Int(numSamples),
                                s.outputBuffer.capacity - s.outputBuffer.count)
                    //s.outputBuffer.append(contentsOf:
                    //            (0..<n).map{ComplexSamples.Element(Float(xi[$0]) * SHORT_SCALE,
                    //                                               Float(xq[$0]) * SHORT_SCALE)})
                    //---
                    //let xiBuf = UnsafeBufferPointer(start:xi, count:n),
                    //    xqBuf = UnsafeBufferPointer(start:xq, count:n)
                    //s.outputBuffer.append(real: xiBuf.map{Float($0) * SHORT_SCALE},
                    //                                imag: xqBuf.map{Float($0) * SHORT_SCALE})
                    // both attempts above seem to discard reserved capacity, which is important
                    // for performance
                    for j in 0..<n {
                        s.outputBuffer.append(ComplexSamples.Element(
                                                                real: Float(xi[j]) * SHORT_SCALE,
                                                                imag: Float(xq[j]) * SHORT_SCALE))
                    }
                    s.overflow += (Int(numSamples)-n)
                s.outputFill.signal()
                s.outputFill.unlock()
//                if n < Int(numSamples) {
//                    print(SDRplay.CLASS_NAME, "streamCallback",
//                          "buffer", s.outputIndex, s.outputBuffer.count,
//                          "overflow",(Int(numSamples)-n),s.overflow)
//                }
            }
            //
        }
        s.callbackTime.stop()
        if grChanged != 0 { print(SDRplay.CLASS_NAME,"Stream gain reduction changed",grChanged); }
        if rfChanged != 0 { print(SDRplay.CLASS_NAME,"Stream tuner frequency changed",rfChanged); }
        if fsChanged != 0 { print(SDRplay.CLASS_NAME,"Stream sample frequency changed",fsChanged); }
        if reset     != 0 { print(SDRplay.CLASS_NAME,"Stream reset"); }
        if hwRemoved != 0 { print(SDRplay.CLASS_NAME,"Stream hardware removed!"); }
    }
    var callbackTime = TimeReport(subjectName:"SDRplay streamCallback", highnS:UInt64(1/2e6*1008*1e9))
    var callbackLockTime = TimeReport(subjectName:"SDRplay streamCallback lock")

    /// This callback is triggered whenever a gain update occurs.
    /// - Parameter gRdB: New IF gain reduction value applied by the gain update. This parameter is also used to pass messages from API to the application as defined in section 2.12.
    /// - Parameter lnaGRdB: LNA gain reduction value.
    /// - Parameter cbContext: Pointer to context passed into mir_sdr_StreamInit().
    private static let gainChangeCallback: mir_sdr_GainChangeCallback_t = {
                (gRdB:UInt32,
                lnaGRdB:UInt32,
                cbContext:Optional<UnsafeMutableRawPointer>) in
        let s = Unmanaged<SDRplay>.fromOpaque(cbContext!).takeUnretainedValue()
        print(SDRplay.CLASS_NAME,"GainChange IF",gRdB,"LNA",lnaGRdB)
        // from SoapySDRPlay/Streaming.cpp gr_callback
        if gRdB < mir_sdr_GAIN_MESSAGE_START_ID.rawValue {
            // is a calibrated gain value
            if gRdB < 200 {
                s.gainRedndB = Int32(gRdB);
            }
        } else if gRdB == mir_sdr_ADC_OVERLOAD_DETECTED.rawValue {
            failIfError(mir_sdr_GainChangeCallbackMessageReceived(), "GainChangeCallbackMessageReceived");
        } else { // OVERLOAD CORRECTED
            failIfError(mir_sdr_GainChangeCallbackMessageReceived(), "GainChangeCallbackMessageReceived");
        }
    }
        
    public func startReceive() {
        sampleCount = 0
        // enable AGC with default rate and a setPoint of -30dBfs
        SDRplay.failIfError(mir_sdr_AgcControl(agcMode, agcSetPoint, /*unused*/0, /*unused*/0,
                                               /*unused*/0, /*sync update*/0, lnaState),
                            "AgcControl");
        /* FUTURE
        if (decimation) failIfError(mir_sdr_DecimateControl(1, decimation, 0), "DecimateControl");
        else failIfError(mir_sdr_DecimateControl(0, 4, 0), "DecimateControl"); // disabled
        */
        // gainChangeCallback can be called from mir_sdr_StreamInit and modify gainRedndB, so it
        // is copied to a temporary and then back
        var temporaryGainRedndB = gainRedndB
        SDRplay.failIfError(mir_sdr_StreamInit(&temporaryGainRedndB, sampleHz/MHZ, tuneHz/MHZ, bandwidthMode,
                                               ifMode, lnaState, &gainRedndBSystem, gainRednMode, &samplesPerCallback,
                                               SDRplay.streamCallback, SDRplay.gainChangeCallback,
                                               Unmanaged<SDRplay>.passUnretained(self).toOpaque()),
                            "StreamInit")
        gainRedndB = temporaryGainRedndB
        print("SDRplay StreamInit", "Fs",sampleHz, "RF",tuneHz, "BW",bandwidthMode.rawValue,
              "SPC",samplesPerCallback)
        streamInit = true
    }
    
    public func stopReceive() {
        if streamInit {
            SDRplay.failIfError(mir_sdr_StreamUninit(), "StreamUninit")
            streamInit = false
            //if buffers[outputIndex].count > 0 { produce(clear:true, subLock:outputFill) }
            sampleCount = 0
        }
    }
    public let processTime = TimeReport(subjectName: "SDRplay process")//, highnS: 10_700_000)

    public func receiveLoop() {
        while !Thread.current.isCancelled {
            outputFill.lock()
                while outputBuffer.count == 0 { outputFill.wait() }
                if overflow > 0 {
                    print(SDRplay.CLASS_NAME, outputBuffer.count, "overflow", overflow)
                    overflow = 0
                }
            outputFill.unlock()
            sampleCount += UInt64(outputBuffer.count)
            //print(SDRplay.CLASS_NAME, outputBuffer.count)
            if !streamInit { continue }  // has been stopped

            processTime.start()
            produce(clear:true, subLock:outputFill)
            processTime.stop()
        }
        print(name ?? "unknown", "receiveLoop exit")
        //stopReceive()
    }

    public static let OptAntenna = "Antenna";
    public static let OptAntenna_A = "Antenna A";
    public static let OptAntenna_B = "Antenna B";
    public static let OptAntenna_Hi_Z = "Hi-Z";
    public static let OptBiasTee = "biasT_ctrl";
    public static let Opt_Disable = "disable";
    public static let OptRFNotch = "rfnotch_ctrl";
    public static let OptAGCMode = "agc_mode";
    public static let OptAGCMode_100Hz = "100Hz";
    public static let OptAGCMode_50Hz = "50Hz";
    public static let OptAGCMode_5Hz = "5Hz";
    public static let OptAGCMode_Disable = "disable";
    public static let OptDebug = "debug";
    public static let OptGainReduction = "gain_reduction";
    public static let OptAGCSetPoint = "agc_set_point";
    public static let OptDecimation = "decimation"
    public static let OptTuner_1_50_ohm = "Tuner 1 50 ohm"
    public static let OptTuner_2_50_ohm = "Tuner 2 50 ohm"
    public static let OptTuner_1_Hi_Z = "Tuner 1 Hi-Z"

    public func setOption(_ option: String, _ value: String) {
        var en: Int32
        // gainChangeCallback can be called from mir_sdr_Reinit and modify gainRedndB, so it
        // is copied to a temporary and then back. Documentation does not state if there will
        // be a difference in the values.
        var temporaryGainRedndB = gainRedndB
        if option == SDRplay.OptAntenna {
            if hwVersion == 2 {
                var antenna = mir_sdr_RSPII_ANTENNA_A
                var changeToAntennaA_B = false
                if value == SDRplay.OptAntenna_A {
                    antenna = mir_sdr_RSPII_ANTENNA_A
                    changeToAntennaA_B = true
                } else if value == SDRplay.OptAntenna_B {
                    antenna = mir_sdr_RSPII_ANTENNA_B
                    changeToAntennaA_B = true
                } else if value == SDRplay.OptAntenna_Hi_Z {
                    amPort = 1
                    SDRplay.failIfError(mir_sdr_AmPortSelect(amPort), "AmPortSelect")
                    if streamInit {
                        SDRplay.failIfError(mir_sdr_Reinit(&temporaryGainRedndB,
                                                   0.0, 0.0, mir_sdr_BW_Undefined,
                                                   mir_sdr_IF_Undefined, mir_sdr_LO_Undefined,
                                                   lnaState, &gainRedndBSystem,
                                                   mir_sdr_USE_RSP_SET_GR, &samplesPerCallback,
                                                   mir_sdr_CHANGE_AM_PORT),
                                    "CHANGE_AM_PORT")
                        gainRedndB = temporaryGainRedndB
                    }
                } else {
                    SDRplay.failIfError(mir_sdr_InvalidParam, value);
                }
                if changeToAntennaA_B {
                    //if we are currently High_Z, make the switch first.
                    if amPort == 1 {
                        amPort = 0
                        SDRplay.failIfError(mir_sdr_AmPortSelect(amPort), "AmPortSelect")
                        SDRplay.failIfError(mir_sdr_RSPII_AntennaControl(antenna), "RSPII_AntennaControl")
                        if (streamInit) {
                            SDRplay.failIfError(mir_sdr_Reinit(&temporaryGainRedndB,
                                                       0.0, 0.0, mir_sdr_BW_Undefined,
                                                       mir_sdr_IF_Undefined, mir_sdr_LO_Undefined,
                                                       lnaState, &gainRedndBSystem,
                                                       mir_sdr_USE_RSP_SET_GR, &samplesPerCallback,
                                                       mir_sdr_CHANGE_AM_PORT),
                                        "CHANGE_AM_PORT")
                            gainRedndB = temporaryGainRedndB
                        }
                    } else {
                        SDRplay.failIfError(mir_sdr_RSPII_AntennaControl(antenna), "RSPII_AntennaControl")
                    }
                }
            } else if hwVersion == 3 {
                var changeToTuner1_2 = false
                if value == "Tuner 1 50 ohm" {
                    amPort = 0
                    if (tunerSelect != mir_sdr_rspDuo_Tuner_1) {
                        tunerSelect = mir_sdr_rspDuo_Tuner_1
                        changeToTuner1_2 = true
                    }
                } else if value == "Tuner 2 50 ohm" {
                    amPort = 0
                    if (tunerSelect != mir_sdr_rspDuo_Tuner_2) {
                        tunerSelect = mir_sdr_rspDuo_Tuner_2
                        changeToTuner1_2 = true
                    }
                } else if value == "Tuner 1 HiZ" {
                    amPort = 1
                    if (tunerSelect != mir_sdr_rspDuo_Tuner_1) {
                        tunerSelect = mir_sdr_rspDuo_Tuner_1
                        changeToTuner1_2 = true
                    }
                } else {
                    SDRplay.failIfError(mir_sdr_InvalidParam, value)
                }
                if changeToTuner1_2 {
                     SDRplay.failIfError(mir_sdr_rspDuo_TunerSel(tunerSelect), "rspDuo_TunerSel")
                }
                SDRplay.failIfError(mir_sdr_AmPortSelect(amPort), "AmPortSelect")
                if streamInit {
                    SDRplay.failIfError(mir_sdr_Reinit(&temporaryGainRedndB,
                                               0.0, 0.0, mir_sdr_BW_Undefined,
                                               mir_sdr_IF_Undefined, mir_sdr_LO_Undefined,
                                               lnaState, &gainRedndBSystem,
                                               mir_sdr_USE_RSP_SET_GR, &samplesPerCallback,
                                               mir_sdr_CHANGE_AM_PORT),
                                "CHANGE_AM_PORT")
                    gainRedndB = temporaryGainRedndB
                }
            } else {
                SDRplay.failIfError(mir_sdr_InvalidParam, value);
            }

        } else if option == SDRplay.OptBiasTee {
            en = (value == SDRplay.Opt_Disable) ? 0 : 1
            if hwVersion == 2 {
                SDRplay.failIfError(mir_sdr_RSPII_BiasTControl(UInt32(en)), "RSPII_BiasTControl");
            } else if hwVersion == 3 {
                SDRplay.failIfError(mir_sdr_rspDuo_BiasT(en), "rspDuo_BiasT");
            } else if hwVersion > 253 {
                SDRplay.failIfError(mir_sdr_rsp1a_BiasT(en), "rsp1a_BiasT");
            } else {
                SDRplay.failIfError(mir_sdr_InvalidParam, value);
            }

        } else if option == SDRplay.OptRFNotch {
            en = (value == SDRplay.Opt_Disable) ? 0 : 1
            if hwVersion == 2 {
                SDRplay.failIfError(mir_sdr_RSPII_RfNotchEnable(UInt32(en)), "RSPII_RfNotchEnable");
            } else if hwVersion == 3 {
                if tunerSelect == mir_sdr_rspDuo_Tuner_1 && amPort == 1 {
                    SDRplay.failIfError(mir_sdr_rspDuo_Tuner1AmNotch(en), "rspDuo_Tuner1AmNotch");
                }
                if amPort == 0 {
                    SDRplay.failIfError(mir_sdr_rspDuo_BroadcastNotch(en), "rspDuo_BroadcastNotch");
                }
            } else if hwVersion > 253 {
                SDRplay.failIfError(mir_sdr_rsp1a_BroadcastNotch(en), "rsp1a_BroadcastNotch");
            } else {
                SDRplay.failIfError(mir_sdr_InvalidParam, value);
            }

        } else if option == SDRplay.OptAGCMode {
            var m = agcMode;
            if value == SDRplay.OptAGCMode_100Hz {
                m = mir_sdr_AGC_100HZ;
            } else if value == SDRplay.OptAGCMode_50Hz {
                m = mir_sdr_AGC_50HZ;
            } else if value == SDRplay.OptAGCMode_5Hz {
                m = mir_sdr_AGC_5HZ;
            } else if value == SDRplay.Opt_Disable {
                m = mir_sdr_AGC_DISABLE;
            } else {
                SDRplay.failIfError(mir_sdr_InvalidParam, value);
            }
            agcMode = m;
            SDRplay.failIfError(mir_sdr_AgcControl(m, agcSetPoint, 0, 0, 0, 0, lnaState), "AgcControl");
     
        } else if option == SDRplay.OptDebug {
            en = (value == SDRplay.Opt_Disable) ? 0 : 1
            SDRplay.failIfError(mir_sdr_DebugEnable(UInt32(en)), "DebugEnable");
            
        } else {
            SDRplay.failIfError(mir_sdr_InvalidParam, option);
            
        }
    }

    public func setOption(_ option: String, _ value: Int) {
        if option == SDRplay.OptGainReduction {
            SDRplay.failIfError(mir_sdr_SetGr(Int32(value), 1/*absolute value*/, 1/*synchronous*/), "SetGr");

        } else if option == SDRplay.OptAGCSetPoint {
            let sp = Int32(value);
            SDRplay.failIfError(mir_sdr_AgcControl(agcMode, sp, 0, 0, 0, 0, lnaState), "AgcControl");
            agcSetPoint = sp;

        } else if option == SDRplay.OptDecimation {
            SDRplay.failIfError(mir_sdr_DecimateControl(/*enable*/1, /*decimationFactor*/UInt32(value), /*wideBandSignal*/0), "DecimateControl");
            decimate = value

        } else {
            SDRplay.failIfError(mir_sdr_InvalidParam, option);
        }
    }
    
    public func printTimes() {
        processTime.printAccumulated(reset:true)
        //threadWaitTime.printAccumulated(reset:true)
        //sinkProcessTime.printAccumulated(reset:true)
        //callbackTime.printAccumulated(reset:true)
        //callbackLockTime.printAccumulated(reset:true)
    }

}
