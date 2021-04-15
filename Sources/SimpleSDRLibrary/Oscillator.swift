//
//  Oscillator.swift
//  SimpleSDR3
//
//  Created by Andy Hooper on 2020-01-22.
//  Copyright © 2020 Andy Hooper. All rights reserved.
//

import func CoreFoundation.cosf
import func CoreFoundation.sinf
import func CoreFoundation.sqrtf

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
    var phase, step: Float // fraction of a cycle
    
    public init(signalHz:Double, sampleHz:Double, level:Float=1.0) {
        precondition(sampleHz >= signalHz * 2, "sampleHz must be >= 2 * signalHz")
        table = (0..<TABLE_SIZE).map{Element.oscillator(2*Float.pi*Float($0)/Float(TABLE_SIZE), level)}
        phase = 0
        step = Float(TABLE_SIZE) * Float(signalHz / sampleHz)
    }

    mutating func next()->Element? {
        // never returns nil, but Optional is required for protocol conformance
        while phase < 0 {
            phase += Float(TABLE_SIZE)
        }
        while (phase+0.5) >= Float(TABLE_SIZE) {
            phase -= Float(TABLE_SIZE)
        }
        let v = table[Int(phase+0.5)]
        phase += step
        return v
    }
    
    mutating func setFrequency(_ f:Float) {
        step = Float(TABLE_SIZE) * f
    }
    
    mutating func setPhase(_ p:Float) {
        phase = Float(TABLE_SIZE) * p
    }
    
    mutating func adjustFrequency(_ d:Float) {
        step += Float(TABLE_SIZE) * d
    }
    
    mutating func adjustPhase(_ d:Float) {
        phase += Float(TABLE_SIZE) * d
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
        output.removeAll(keepingCapacity:true)
        for _ in 0..<numSamples {
            let n:Samples.Element = osc.next()!
            output.append(n)
        }
    }
    
    override public func sampleFrequency() -> Double {
        return Double(sampleHz)
    }
    
    func setFrequency(_ d:Float) {
        osc.setFrequency(d / (2*Float.pi))
        generate(&outputBuffer)
        generate(&produceBuffer)
    }
    
    func setPhase(_ d:Float) {
        osc.setPhase(d / (2*Float.pi))
        generate(&outputBuffer)
        generate(&produceBuffer)
    }

    
    func adjustFrequency(_ d:Float) {
        osc.adjustFrequency(d / (2*Float.pi))
        generate(&outputBuffer)
        generate(&produceBuffer)
    }
    
    func adjustPhase(_ d:Float) {
        osc.adjustPhase(d / (2*Float.pi))
        generate(&outputBuffer)
        generate(&produceBuffer)
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
        for ev in x { out.append(ev * osc.next()! )}
    }
    
    func setFrequency(_ d:Float) {
        osc.setFrequency(d / (2*Float.pi))
    }
    
    func setPhase(_ d:Float) {
        osc.setPhase(d / (2*Float.pi))
    }

    
    func adjustFrequency(_ d:Float) {
        osc.adjustFrequency(d / (2*Float.pi))

    }
    
    func adjustPhase(_ d:Float) {
        osc.adjustPhase(d / (2*Float.pi))
    }

}

public class PLL:BufferedStage<ComplexSamples,ComplexSamples> {
    public static let DEFAULT_BANDWIDTH = Float(0.1)
    private var osc:OscillatorLookup<ComplexSamples.Element>
    var alpha, beta: Float // loop adjustment bandwidth

    public init<S:SourceProtocol>(source:S?,
                                  signalHz:Double,
                                  loopBandwidth:Float=PLL.DEFAULT_BANDWIDTH)
                    where S.Output == Input {
        let sampleHz = source!.sampleFrequency()
        osc = OscillatorLookup<ComplexSamples.Element>(signalHz: signalHz, sampleHz: sampleHz)
        alpha = loopBandwidth
        beta = sqrtf(alpha)
        super.init("PLL", source:source)
    }
    
    func adjustFrequency(_ d:Float) {
        osc.adjustFrequency(d / (2*Float.pi))
    }
    
    func adjustPhase(_ d:Float) {
        osc.adjustPhase(d / (2*Float.pi))
    }

    func adjust(_ d:Float) {
        adjustFrequency(d * alpha)
        adjustPhase(d * beta)
    }
    
    func setBandwidth(_ bw:Float) {
        alpha = bw
        beta = sqrtf(alpha)
    }

    override func process(_ x:Input, _ out:inout Output) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        out.removeAll()
        for ev in x { out.append(osc.next()!); /*TODO adjust(ev)*/ }
    }
    
}
