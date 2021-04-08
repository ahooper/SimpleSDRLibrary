//
//  RealToComplex.swift
//  SimpleSDR3
//
//  Created by Andy Hooper on 2020-02-29.
//  Copyright © 2020 Andy Hooper. All rights reserved.
//

public class RealToComplex:BufferedStage<RealSamples,ComplexSamples> {

    public init<S:SourceProtocol>(source:S?) where S.Output == Input {
        super.init("RealToComplex", source:source)
    }
    
    override func process(_ x:RealSamples, _ out:inout ComplexSamples) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        for i in 0..<inCount {
            out[i] =  ComplexSamples.Element(x[i])
        }
    }
}
