//
//  AMDemodulate.swift
//  
//
//  Created by Andy Hooper on 2020-05-05.
//

public class AMDemodulate:BufferedStage<ComplexSamples,RealSamples> {
    let modulationIndex:Float
    
    public init<S:SourceProtocol>(source:S?,
                                  modulationIndex:Float) where S.Output == Input {
        self.modulationIndex = modulationIndex
        super.init("AMDemodulate", source:source)
    }
    
    override func process(_ x:ComplexSamples, _ out:inout RealSamples) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        for i in 0..<inCount {
            // envelope
            out[i] = x[i].modulus() / modulationIndex
            //print(String(format:"%d %.3f", i, out[i]))
        }
    }
}
/*
public class AMDemodulateDSBPLL:BufferedStage<ComplexSamples,RealSamples> {
    let modulationIndex:Float
    let mixer:PLL
    let dcblock:FIRFilter<RealSamples>
    let lowpass:FIRFilter<ComplexSamples>
    let delay:Delay<ComplexSamples>
    
    public init<S:SourceProtocol>(source:S?,
                                  modulationIndex:Float) where S.Output == Input {
        self.modulationIndex = modulationIndex
        let m = 25,
            dcAttenuation = 20.0
        self.mixer = PLL(source:source, signalHz:0, errorEstimator: <#T##PLL.ErrorEstimator##PLL.ErrorEstimator##(PLL.Input.Element, PLL.Output.Element) -> Float#>)
        self.mixer.setBandwidth(0.001)
        self.dcblock = FIRFilter(source: demodulated,
                                 FIRKernel.dcBlock(filterSemiLength: 2*m+1,
                                                   stopBandAttenuation: dcAttenuation))
        self.lowpass = FIRFilter(source: source,
                                 FIRKernel.kaiserLowPass(transitionFrequency: <#T##Float#>,
                                                         sampleFrequency: <#T##Float#>,
                                                         ripple: <#T##Float#>,
                                                         width: <#T##Float#>,
                                                         gain: <#T##Float#>))
        
        self.delay = Delay(source: source, lowpass.Pminus1/2)
        super.init("AMDemodulate", source:source)
        
        /*
         q->m         = 25;

         // create nco, pll objects
         q->mixer = nco_crcf_create(LIQUID_NCO);
         nco_crcf_pll_set_bandwidth(q->mixer,0.001f);

         // carrier suppression filter
         q->dcblock = firfilt_rrrf_create_dc_blocker(q->m, 20.0f);

         // Hilbert transform for single side-band recovery
         q->hilbert = firhilbf_create(q->m, 60.0f);

         // carrier admittance filter for phase-locked loop
         q->lowpass = firfilt_crcf_create_kaiser(2*q->m+1, 0.01f, 40.0f, 0.0f);

         // delay buffer
         q->delay = wdelaycf_create(q->m);

         // set appropriate demod function pointer
         q->demod = NULL;
         if (q->type == LIQUID_AMPMODEM_DSB) {
             // double side-band
             q->demod = q->suppressed_carrier ?
                 ampmodem_demod_dsb_pll_costas :
                 //ampmodem_demod_dsb_peak_detect;
                 ampmodem_demod_dsb_pll_carrier;
         } else {
             // single side-band
             q->demod = q->suppressed_carrier ? ampmodem_demod_ssb : ampmodem_demod_ssb_pll_carrier;
         }

         */
    }
    /*
    
     source:x-+->lowpass:x0-->mixer0:v0-->phase err
              |                 ↑             ↓
              |                 +<-----------PLL
              |                 ↓
              +->delay:x1---->mixer1:v1-->real / modIndex:m-->dcblock:y-->sink
   
     */

    var x0, x1, v0, v1:ComplexSamples
    
    override func process(_ x:ComplexSamples, _ out:inout RealSamples) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        lowpass.process(x, &x0)
        delay.process(x, &x1)
        mix0.process(v0, &v0)
        mix1.process(v1, &v1)
        let r = v1.map{$0.real / modulationIndex}
        dcblock.process(r, &out)
    }
}
*/
