//
//  SpectrumData.swift
//  SimpleSDR3
//
//  Created by Andy Hooper on 2020-02-07.
//  Copyright © 2020 Andy Hooper. All rights reserved.
//
//  liquid-dsp-1.3.1/src/fft/src/spgram.c
//
//  https://developer.apple.com/library/archive/documentation/Performance/Conceptual/vDSP_Programming_Guide/Introduction/Introduction.html
//  https://developer.apple.com/documentation/accelerate/vdsp/fast_fourier_transforms/finding_the_component_frequencies_in_a_composite_sine_wave?language=objc
//  https://developer.apple.com/documentation/accelerate/vdsp/vector_generation/using_windowing_with_discrete_fourier_transforms
//
//  Apple doc. says "Use the DFT routines instead of these wherever possible.", but does not explain why. No
//  answer in forum https://forums.developer.apple.com/thread/23321
//
//  Various similar vDSP FFT usage:
//  http://www.myuiviews.com/2016/03/04/visualizing-audio-frequency-spectrum-on-ios-via-accelerate-vdsp-fast-fourier-transform.html
//  https://github.com/AlbanPerli/iOS-Spectrogram
//  https://gist.github.com/hotpaw2/f108a3c785c7287293d7e1e81390c20b
//  https://stackoverflow.com/q/32891012
//  https://github.com/jasminlapalme/caplaythrough-swift/blob/master/CAPlayThroughSwift/FFTHelper.swift
//  https://github.com/liscio/SMUGMath-Swift/blob/master/SMUGMath/FFTOperations.swift

import Accelerate.vecLib.vDSP

public class SpectrumData:Sink<ComplexSamples> {
    let log2Size:UInt
    public let N:Int
    let dft:vDSP_DFT_Setup
    var window:[Float]
    var fftTime, fftFreq, fftFMagSq:SplitComplex
    var fftSum:[Float]
    public var numberSummed:UInt
    var carry:Input
    var zeroReference:[Float]
    let readLock:NSLock
    var sumInitialValue = Float(1.0e-15) //-150dB ensure non-zero for logarithm, need a var for vDSP_vfill
    public var centreHz:Double = 0
    
    public init<S:SourceProtocol>(_ name:String, source:S?, asThread:Bool=false,
                           log2Size:UInt)
                   where S.Output == Input {
        self.log2Size = log2Size
        N = 1 << log2Size
        let noPrevious = OpaquePointer(bitPattern: 0) // NULL
        dft = vDSP_DFT_zop_CreateSetup(noPrevious, vDSP_Length(N), vDSP_DFT_Direction.FORWARD)!
        window = [Float](repeating:1.0, count:N)
        // TODO: Configurable window length <= N, default N/2
        // TODO: Configurable overlap (delay), default N/4
        vDSP_blkman_window(/*output*/&window, vDSP_Length(window.count), 0)
        // TODO: window from harris 1978 paper
        var sumsq: Float = 0 // scale to unit window, and apply FFT factor
        vDSP_svesq(window, 1, /*output*/&sumsq, vDSP_Length(N))
        var scale = sqrtf(2) / ( sqrtf(sumsq / Float(window.count)) * sqrtf(Float(N)) )
        vDSP_vsmul(window, 1, &scale, &window, 1, vDSP_Length(window.count))
        // initializing with NaN gives an exception for debugging if a value
        // is read before being set
        fftTime = SplitComplex(repeating:Input.nan, count:N)
        fftFreq = SplitComplex(repeating:Input.nan, count:N)
        fftFMagSq = SplitComplex(repeating:Input.zero, count:N)
        fftSum = [Float](repeating:sumInitialValue, count:N)
        carry = Input()
        carry.reserveCapacity(N)
        numberSummed = 0
        zeroReference = [Float](repeating:1.0, count:N)  // 1 = full scale
        readLock = NSLock()
        super.init(name, source:source, asThread:asThread)
    }
    
    deinit {
        vDSP_DFT_DestroySetup(dft)
    }
    
    public func sampleFrequency()-> Double {
        if let source = source { return source.sampleFrequency() }
        else { return Double.nan }
    }

    /// run one FFT block and sum the result for averaging
    func transformAndSum(_ samples: Input, _ range:Range<Int>) {
        //print("SpectrumData transformAndSum",samples.count,range)
        precondition(range.count == N)
        // apply window
        for i in 0..<N {
            fftTime[i] = samples[i] * window[i]
        }
        // perform FFT
        assert(fftTime.count==N && fftFreq.count==N)
        SplitComplexOps.DFT_Execute(dft, fftTime, fftFreq)
        // multiply by conjugate to get magnitude squared, which will be in the real part
        SplitComplexOps.multiply(a: fftFreq, aConjugate: true, b: fftFreq, c: fftFMagSq)
        // add to sum for averaging TODO: integrating factors gamma,alpha
        let sp = fftFMagSq.unsafePointers()
        vDSP_vadd(sp.realp, 1,
                  &fftSum, 1,
                  /*output*/&fftSum, 1,
                  vDSP_Length(N))
        numberSummed += 1
    }

    /// match sample stream to FFT size
    // most of the FFT calls are made directly from the input area,
    // with a carry over between calls for the remainder

    override public func process(_ input: ComplexSamples) {
        var sampleIndex = 0
        readLock.lock(); defer {readLock.unlock()}
        if carry.count > 0 {
            if carry.count + input.count < N {
                carry.append(rangeOf:input, 0..<input.count)
                return
            }
            sampleIndex += N - carry.count
            carry.append(rangeOf:input, 0..<sampleIndex)
            assert(carry.count == N)
            transformAndSum(carry, 0..<carry.count)
            carry.removeAll(keepingCapacity:true)
        }
        while sampleIndex + N <= input.count {
            transformAndSum(input, sampleIndex..<(sampleIndex+N))
            sampleIndex += N
        }
        if sampleIndex < input.count {
            carry.append(rangeOf:input, sampleIndex..<input.count)
        }
    }
    
    /// Complete the FFT average, convert to decibels, and rotate
    /// 0 frequency to the middle for display.
    public func getdBandClear(_ data :inout [Float]) {
        precondition(data.count == N)
        if numberSummed == 0 {
            // no data
            var fill = 10.0*log10f(sumInitialValue) // need mutable for vDSP_vfill
            vDSP_vfill(&fill, &data, 1, vDSP_Length(N))
            return
        }
        assert(fftSum.count == N)
        readLock.lock(); defer {readLock.unlock()}
        // calculate log10(magnitude squared)*10 (decibels)
        // the squaring is not scaled out so this is now 20*log(magnitude), i.e. power
        vDSP_vdbcon(&fftSum, 1,
                    &zeroReference,
                    /*output*/&fftSum, 1,
                    vDSP_Length(N), 0/*amplitude*/)
        var scale = -10.0*log10f(Float(numberSummed)) // divide for average by subtracting logarithm
        // apply scale and rotate freq[0] to centre of data array [N/2]
        let Nover2 = N/2
        data.withUnsafeMutableBufferPointer { dataPtr in
            fftSum.withUnsafeBufferPointer { sumPtr in
                vDSP_vsadd(sumPtr.baseAddress!, 1,
                           &scale,
                           /*output*/dataPtr.baseAddress!.advanced(by: Int(Nover2)), 1,
                           vDSP_Length(Nover2))
                vDSP_vsadd(sumPtr.baseAddress!.advanced(by: Int(Nover2)), 1,
                           &scale,
                           /*output*/dataPtr.baseAddress!, 1,
                           vDSP_Length(Nover2))
            }
        }
        // clear accumulation, but leave carrying samples
        vDSP_vfill(&sumInitialValue, &fftSum, 1, vDSP_Length(N))
        numberSummed = 0
        //carry.removeAll(keepingCapacity: true)
    }

}
