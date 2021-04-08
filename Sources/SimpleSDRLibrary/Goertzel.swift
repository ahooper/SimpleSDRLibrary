//
//  Goertzel.swift
//  
//
//  Created by Andy Hooper on 2020-11-25.
//
// Lyons, R. Understanding Digital Signal Processing, 3 ed., S13.17
// https://en.wikipedia.org/wiki/Goertzel_algorithm
// https://www.dsprelated.com/showarticle/495.php
// https://www.researchgate.net/publication/257879807_Goertzel_algorithm_generalized_to_non-integer_multiples_of_fundamental_frequency
// https://www.embedded.com/design/real-world-applications/4401754/Single-tone-detection-with-the-Goertzel-algorithm
// https://cnx.org/contents/kw4ccwOo@5/Goertzel-s-Algorithm
// http://www.mstarlabs.com/dsp/goertzel/goertzel.html
// https://pdfs.semanticscholar.org/a5e4/d0faf65627374b1ac82c3c79006d010173c9.pdf

import func CoreFoundation.cos
import func CoreFoundation.sin
import func CoreFoundation.ceil

#if OMITTED
// TODO does not compile on Xcode Swift 5.3.1

public class Goertzel<Samples:DSPSamples>:BufferedStage<Samples,ComplexSamples> {
    let N: Int
    let k, alpha, beta: Float
    let B: Samples.Element
    let C, D: ComplexSamples.Element
    var n: Int
    var w1, w2: Samples.Element

    public init<S:SourceProtocol>(source:S?, targetFrequencyHz:Float, sampleFrequency:Float, Nfft:Int) where S.Output == Input {
        precondition(Nfft >= 1)
        precondition(targetFrequencyHz < sampleFrequency)
        N = Nfft
        k = targetFrequencyHz * Float(N) / sampleFrequency
        alpha = 2.0 * Float.pi * k / Float(N)
        beta  = 2.0 * Float.pi * k * Float(N-1) / Float(N)
        B = Samples.Element(2.0 * cos(alpha))
        C = ComplexSamples.Element(cos(alpha), -sin(alpha)) //e^−jα = cos(-α) + i sin(−α) = cos α - i sin α
        D = ComplexSamples.Element(cos(beta), -sin(beta)) //e^−jβ
        n = 0
        w2 = 0; w1 = 0
        super.init("Goertzel", source:source)
    }
    
    public convenience init<S:SourceProtocol>(source:S, targetFrequencyHz:Float, Nfft:Int) where S.Output == Input {
        self.init(source: source,
                  targetFrequencyHz: targetFrequencyHz,
                  sampleFrequency: Float(source.sampleFrequency()),
                  Nfft: Nfft)
    }

    public override func sampleFrequency() -> Double {
        if let source = source { return ceil(source.sampleFrequency() / Double(N)) }
        else { return Double.nan }
    }

    override public func process(_ x:Samples, _ out:inout ComplexSamples) {
        let inCount = x.count
        out.resize(0)
        for i in 0..<inCount {
            n += 1
            let w0 = x[i] + B * w1 - w2
            if n < N {
                w2 = w1
                w1 = w0
            } else { // final in block
                //let y = (w0 - w1 * C) * D
                    // on Apple Swift version 5.3.1:
                    // Referencing operator function '-' on 'SIMD' requires that 'Samples.Element' conform to 'SIMD'
                let y = (w0 - w1 * C) * D
                out.append(y/Float(N))
                n = 0
                w2 = 0; w1 = 0
            }
        }
    }

}

public class GoertzelDetect<Samples:DSPSamples>:BufferedStage<Samples,RealSamples> {
    let N: Int
    let k, alpha, beta: Float
    let B: Samples.Element
    let C, D: ComplexSamples.Element
    var n: Int
    var w1, w2: Samples.Element

    public init<S:SourceProtocol>(source:S?, targetFrequencyHz:Float, sampleFrequency:Float, Nfft:Int) where S.Output == Input {
        precondition(Nfft >= 1)
        precondition(targetFrequencyHz < sampleFrequency)
        N = Nfft
        k = targetFrequencyHz * Float(N) / sampleFrequency
        alpha = 2.0 * Float.pi * k / Float(N)
        beta  = 2.0 * Float.pi * k * Float(N-1) / Float(N)
        B = Samples.Element(2.0 * cos(alpha))
        C = ComplexSamples.Element(cos(alpha), -sin(alpha)) //e^−jα = cos(-α) + i sin(−α) = cos α - i sin α
        D = ComplexSamples.Element(cos(beta), -sin(beta)) //e^−jβ
        n = 0
        w2 = 0; w1 = 0
        super.init("Goertzel", source:source)
    }
    
    public convenience init<S:SourceProtocol>(source:S, targetFrequencyHz:Float, Nfft:Int) where S.Output == Input {
        self.init(source: source,
                  targetFrequencyHz: targetFrequencyHz,
                  sampleFrequency: Float(source.sampleFrequency()),
                  Nfft: Nfft)
    }

    public override func sampleFrequency() -> Double {
        if let source = source { return ceil(source.sampleFrequency() / Double(N)) }
        else { return Double.nan }
    }

    override public func process(_ x:Samples, _ out:inout RealSamples) {
        let inCount = x.count
        out.resize(0)
        for i in 0..<inCount {
            n += 1
            let w0 = x[i] + B * w1 - w2
            if n < N {
                w2 = w1
                w1 = w0
            } else { // final in block
                let y = (w0 - w1 * C) * D
                out.append(y/Float(N))
                n = 0
                w2 = 0; w1 = 0
            }
        }
    }

}

#endif
