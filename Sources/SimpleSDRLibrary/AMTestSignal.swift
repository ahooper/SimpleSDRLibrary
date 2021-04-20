//
//  AMTestSignal.swift
//  
//
//  Created by Andy Hooper on 2020-09-08.
//

import func CoreFoundation.cosf
import func CoreFoundation.sinf

public class AMTestSignal:BufferedStage<RealSamples,ComplexSamples> {
    let carrierFrequency, modulationIndex:Float
    let w:Float
    private var phase:Float
    static let TWO_PI: Float = 2.0 * Float.pi

    public init<S:SourceProtocol>(source:S?,
                                  carrierHz:Float,
                                  modulationIndex:Float) where S.Output == Input {
        self.carrierFrequency = carrierHz / Float(source!.sampleFrequency())
        self.modulationIndex = modulationIndex
        phase = Float(0)
        w = AMTestSignal.TWO_PI * carrierFrequency
        super.init("AMTestSignal", source:source)
     }
    
    override public func process(_ x:Input, _ out:inout Output) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        //print(inCount, phase, "", terminator:"")
        for i in 0..<inCount {
            let s = x[i] * modulationIndex + 1.0
            out[i] = Output.Element.oscillator(phase, s)
            //print(i,x[i],s,phase,out[i].modulus())
            phase += w
            if phase >= AMTestSignal.TWO_PI { phase -= AMTestSignal.TWO_PI }
        }
        //print(out[0],out[inCount-1],phase,w)
    }
}
