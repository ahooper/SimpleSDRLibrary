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
    let mixer:OscillatorComplex
    let dcblock:FIRFilter<RealSamples>
    let lowpass:FIRFilter<ComplexSamples>
    let delay:Delay<ComplexSamples>
    
    public init<S:SourceProtocol>(source:S?,
                                  modulationIndex:Float) where S.Output == Input {
        self.modulationIndex = modulationIndex
        let m = 25,
            dcAttenuation = 20.0
        self.mixer = OscillatorComplex()
        self.mixer.pllBandwidth = 0.001
        self.dcblock = FIRFilter(source: demodulated,
                                 FIRKernel.dcBlock(filterSemiLength: 2*m+1,
                                                   stopBandAttenuation: dcAttenuation))
        self.lowpass = FIRFilter(source: source,
                                 FIRKernel.kaiserLowPass(transitionFrequency: <#T##Float#>,
                                                         sampleFrequency: <#T##Float#>,
                                                         ripple: <#T##Float#>,
                                                         width: <#T##Float#>,
                                                         gain: <#T##Float#>))
        self.delay = Delay(source: source, m)
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
*/
