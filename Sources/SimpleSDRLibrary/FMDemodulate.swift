//
//  FMDemodulate.swift
//  SimpleSDR3
//
//  http://www.hyperdynelabs.com/dspdude/papers/DigRadio_w_mathcad.pdf
//
//  Created by Andy Hooper on 2020-01-25.
//  Copyright © 2020 Andy Hooper. All rights reserved.
//

public class FMDemodulate:BufferedStage<ComplexSamples,RealSamples> {
    let modulationFactor:Float
    let factor:Float
    private var overlap:ComplexSamples.Element
    
    public init<S:SourceProtocol>(source:S?,
         modulationFactor:Float) where S.Output == Input {
        self.modulationFactor = modulationFactor
        self.factor = 1 / (2 * Float.pi * modulationFactor)
        overlap = Input.zero
        super.init("FMDemodulate", source:source)
    }
    
    override func process(_ x:ComplexSamples, _ out:inout RealSamples) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        for i in 0..<inCount {
            // polar discriminator
            let w = overlap.conjugate() * x[i]
            let phase = w.argument()
            overlap = x[i]
            out[i] = phase * factor
        }
    }
}
