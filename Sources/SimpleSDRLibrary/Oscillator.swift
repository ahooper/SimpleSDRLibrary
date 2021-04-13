//
//  Oscillator.swift
//  SimpleSDR3
//
//  Created by Andy Hooper on 2020-01-22.
//  Copyright © 2020 Andy Hooper. All rights reserved.
//

import func CoreFoundation.cosf
import func CoreFoundation.sinf

public class OscillatorReal:BufferedStage<NilSamples,RealSamples> {
    // TODO how to make this generic on samples?
    let signalHz:Float
    let sampleHz:Int
    var level:Float

    private func generate(_ output:inout RealSamples) {
        // initialize repeating samples
        // slight discrepancy if sampleHz is not evenly divisible by signalHz
        let numSamples = Int(Float(sampleHz) / signalHz + 0.5)
        let w = 2.0 * Float32.pi * Float32(signalHz) / Float32(sampleHz)
        for i in 0..<numSamples {
            output.append(RealSamples.Element(cosf(Float32(i) * w) * level))
        }
    }

    public init(signalHz:Float, sampleHz:Int, level:Float=1.0) {
        precondition(Float(sampleHz) >= signalHz * 2, "sampleHz must be >= 2 * signalHz")
        self.signalHz = signalHz
        self.sampleHz = sampleHz
        self.level = level
        super.init("OscillatorReal")
        generate(&outputBuffer)
        generate(&produceBuffer)
    }
    
    override public func sampleFrequency() -> Double {
        return Double(sampleHz)
    }
    
}

public class OscillatorComplex:BufferedStage<NilSamples,ComplexSamples> {
    // TODO how to make this generic on samples?
    let signalHz:Float
    let sampleHz:Int
    var level:Float
    
    private func generate(_ output:inout ComplexSamples) {
        // initialize repeating samples
        // slight discrepancy if sampleHz is not evenly divisible by signalHz
        let numSamples = Int(Float(sampleHz) / signalHz * 10 + 0.5)
        let w = 2.0 * Float32.pi * Float32(signalHz) / Float32(sampleHz)
        for i in 0..<numSamples {
            output.append(ComplexSamples.Element(cosf(Float32(i) * w) * level,
                                                 sinf(Float32(i) * w) * level))
        }
    }

    public init(signalHz:Float, sampleHz:Int, level:Float=1.0) {
        precondition(Float(sampleHz) >= signalHz * 2, "sampleHz must be >= 2 * signalHz")
        self.signalHz = signalHz
        self.sampleHz = sampleHz
        self.level = level
        super.init("OscillatorComplex")
        generate(&outputBuffer)
        generate(&produceBuffer)
    }
    
    override public func sampleFrequency() -> Double {
        return Double(sampleHz)
    }
    
}

public class Oscillator<Samples:DSPSamples>:BufferedStage<NilSamples,Samples> {
    let signalHz:Float
    let sampleHz:Int
    var level:Float
    
    private func generate(_ output:inout Samples) {
        // initialize repeating samples
        // slight discrepancy if sampleHz is not evenly divisible by signalHz
        let numSamples = Int(Float(sampleHz) / signalHz * 10 + 0.5)
        let w = 2.0 * Float32.pi * Float32(signalHz) / Float32(sampleHz)
        for i in 0..<numSamples {
            output.append(Samples.Element.oscillator(Float32(i) * w, level))
        }
    }

    public init(signalHz:Float, sampleHz:Int, level:Float=1.0) {
        precondition(Float(sampleHz) >= signalHz * 2, "sampleHz must be >= 2 * signalHz")
        self.signalHz = signalHz
        self.sampleHz = sampleHz
        self.level = level
        super.init("Oscillator")
        generate(&outputBuffer)
        generate(&produceBuffer)
    }
    
    override public func sampleFrequency() -> Double {
        return Double(sampleHz)
    }
    
}

fileprivate let TABLE_SIZE = 1024

private struct OscillatorLookup<Element:DSPScalar>:IteratorProtocol {
    let table:[Element]
    var phase, step: Float
    
    public init(signalHz:Double, sampleHz:Double, level:Float=1.0) {
        precondition(sampleHz >= signalHz * 2, "sampleHz must be >= 2 * signalHz")
        self.table = (0..<TABLE_SIZE).map{Element.oscillator(2*Float.pi*Float($0)/Float(TABLE_SIZE), level)}
        self.phase = 0
        self.step = Float(TABLE_SIZE) * Float(signalHz / sampleHz)
    }

    mutating func next()->Element? {
        // never returns nil, but Optional is required for protocol conformance
        let v = table[Int(phase+0.5)]
        phase += step
        if (phase+0.5) >= Float(TABLE_SIZE) {
            phase -= Float(TABLE_SIZE)
        } else if phase < 0 {
            phase += Float(TABLE_SIZE)
        }
        return v
    }
    
}

public class OscillatorNew<Samples:DSPSamples>:BufferedStage<NilSamples,Samples> {
    let signalHz, sampleHz:Double
    var level:Float
    private var osc:OscillatorLookup<Samples.Element>

    public init(signalHz:Double, sampleHz:Double, level:Float=1.0) {
        precondition(sampleHz >= signalHz * 2, "sampleHz must be >= 2 * signalHz")
        self.signalHz = signalHz
        self.sampleHz = sampleHz
        self.level = level
        osc = OscillatorLookup<Samples.Element>(signalHz: signalHz, sampleHz: sampleHz)
        super.init("OscillatorNew")
        generate(&outputBuffer)
        generate(&produceBuffer)
    }

    private func generate(_ output:inout Samples) {
        // initialize repeating samples
        // slight discrepancy if sampleHz is not evenly divisible by signalHz
        let numSamples = Int(sampleHz / signalHz * 10 + 0.5)
        for _ in 0..<numSamples {
            let n:Samples.Element? = osc.next()
            output.append(n!)
        }
    }
    
    override public func sampleFrequency() -> Double {
        return Double(sampleHz)
    }
    
}

public class Mixer:BufferedStage<ComplexSamples,ComplexSamples> {
    private var osc:OscillatorLookup<ComplexSamples.Element>

    public init<S:SourceProtocol>(source:S?,
                                  signalHz:Double) where S.Output == Input {
        let sampleHz = source!.sampleFrequency()
        osc = OscillatorLookup<ComplexSamples.Element>(signalHz: signalHz, sampleHz: sampleHz)
        super.init("Mixer", source:source)
    }
    
    override func process(_ x:Input, _ out:inout Output) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        out.removeAll()
        for ev in x { out.append(ev * seq.next() )}
    }
    
}
