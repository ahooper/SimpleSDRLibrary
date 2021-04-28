//
//  AMTestSignal.swift
//  
//
//  Created by Andy Hooper on 2020-09-08.
//

public class AMModulate:BufferedStage<RealSamples,ComplexSamples> {
    let carrier: Oscillator<ComplexSamples>,
        factor:Float,
        suppressedCarrier:Bool

    public init<S:SourceProtocol>(source:S?,
                                  factor:Float=1,
                                  carrierHz:Double,
                                  suppressedCarrier:Bool=false) where S.Output == Input {
        self.carrier =  Oscillator<ComplexSamples>(signalHz: carrierHz,
                                                      sampleHz: source!.sampleFrequency())
        self.factor = factor
        self.suppressedCarrier = suppressedCarrier
        super.init("AMModulate", source:source)
     }
    
    override public func process(_ x:Input, _ out:inout Output) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        carrier.generate(inCount)
        for i in 0..<inCount {
            let s = (suppressedCarrier ? Input.Element(0) : Input.Element(1)) + x[i]*factor
            out[i] = carrier.produceBuffer[i] * s
        }
    }
}
