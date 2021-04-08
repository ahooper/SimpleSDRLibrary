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

public class AMDemodulateDSBPLL:BufferedStage<ComplexSamples,RealSamples> {
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
