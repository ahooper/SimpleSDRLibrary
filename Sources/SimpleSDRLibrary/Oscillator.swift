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

@available(*,deprecated)
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

@available(*,deprecated)
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

@available(*,deprecated)
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

struct OscillatorLookup<Element:DSPScalar>:IteratorProtocol {
    let table:[Element]
    var phase, step: Float // 0..<TABLE_SIZE corresponds to one cycle
    let RADIANS_TO_INDEX: Float = Float(TABLE_SIZE) / (2 * Float.pi)
    let INDEX_TO_RADIANS: Float = (2 * Float.pi) / Float(TABLE_SIZE)

    public init(signalHz:Double, sampleHz:Double, level:Float=1.0) {
        precondition(sampleHz >= signalHz * 2, "sampleHz must be >= 2 * signalHz")
        table = (0..<TABLE_SIZE).map{Element.oscillator(2*Float.pi*Float($0)/Float(TABLE_SIZE), level)}
        phase = 0
        step = Float(TABLE_SIZE) * Float(signalHz / sampleHz)
    }

    mutating func next()->Element? {
        // this infinite sequence never returns nil, but Optional is
        // required for protocol conformance
        while phase < -0.5 {
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
        step = RADIANS_TO_INDEX * f
    }
    
    mutating func setPhase(_ p:Float) {
        phase = RADIANS_TO_INDEX * p
    }
    
    mutating func adjustFrequency(_ d:Float) {
        step += RADIANS_TO_INDEX * d
    }
    
    mutating func adjustPhase(_ d:Float) {
        phase += RADIANS_TO_INDEX * d
    }
    
    func getPhase()->Float {
        return INDEX_TO_RADIANS * phase
    }
    
    func getFrequency()->Float {
        let f = INDEX_TO_RADIANS * step
        return (f > Float.pi) ? (f - 2*Float.pi) : f
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
    }

    public func generate(_ numSamples:Int) {
        assert(outputBuffer.isEmpty)
        outputBuffer.reserveCapacity(numSamples)
        for _ in 0..<numSamples {
            let n:Samples.Element = osc.next()!
            outputBuffer.append(n)
        }
        produce(clear:true)
    }
    
    public func generate() {
        generate(Int(Double(sampleHz) / signalHz * 10 + 0.5))
    }
    
    override public func sampleFrequency() -> Double {
        return Double(sampleHz)
    }
    
    public func setFrequency(_ d:Float) {
        osc.setFrequency(d) //TODO / sampleHz
    }
    
    public func setPhase(_ d:Float) {
        osc.setPhase(d)
    }
    
    public func adjustFrequency(_ d:Float) {
        osc.adjustFrequency(d) //TODO / sampleHz
    }
    
    public func adjustPhase(_ d:Float) {
        osc.adjustPhase(d)
    }
    
    public func getPhase()->Float {
        osc.getPhase()
    }
    
    public func getFrequency()->Float {
        osc.getFrequency() //TODO * sampleHz
    }

}

public class PLL:BufferedStage<ComplexSamples,ComplexSamples> {
    public typealias ErrorEstimator = (Input.Element, Output.Element)->Float
    public static let DEFAULT_BANDWIDTH = Float(0.1)
    var osc:OscillatorLookup<Output.Element>
    let errorEstimator:ErrorEstimator?
    var alpha, beta: Float // loop adjustment bandwidth

    public init<S:SourceProtocol>(source:S?,
                                  signalHz:Double,
                                  errorEstimator: ErrorEstimator?,
                                  loopBandwidth:Float=PLL.DEFAULT_BANDWIDTH)
                    where S.Output == Input {
        let sampleHz = source!.sampleFrequency()
        osc = OscillatorLookup<ComplexSamples.Element>(signalHz: signalHz, sampleHz: sampleHz)
        self.errorEstimator = errorEstimator
        alpha = loopBandwidth
        beta = sqrtf(alpha)
        super.init("PLL", source:source)
    }
    
    public func setFrequency(_ d:Float) {
        osc.setFrequency(d) //TODO / sampleHz
    }
    
    public func setPhase(_ d:Float) {
        osc.setPhase(d)
    }

    public func adjustFrequency(_ d:Float) {
        osc.adjustFrequency(d)
    }
    
    public func adjustPhase(_ d:Float) {
        osc.adjustPhase(d)
    }

    public func adjust(_ d:Float) {
        adjustFrequency(d * alpha)
        adjustPhase(d * beta)
    }
    
    public func getPhase()->Float {
        osc.getPhase()
    }
    
    public func getFrequency()->Float {
        osc.getFrequency() //TODO * sampleHz
    }

    public func setBandwidth(_ bw:Float) {
        alpha = bw
        beta = sqrtf(alpha)
    }

    override func process(_ x:Input, _ out:inout Output) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        out.removeAll()
        for v in x {
            let o = osc.next()!
            out.append(o)
            if let errorEstimator = errorEstimator {
                let e: Float = errorEstimator(v,o)
                //print("PLL",v,o,e)
                adjust(e)
            }
        }
    }
    
}

public class Mixer:PLL {

    public override init<S:SourceProtocol>(source:S?,
                                           signalHz:Double,
                                           errorEstimator: ErrorEstimator?=nil,
                                           loopBandwidth:Float=PLL.DEFAULT_BANDWIDTH)
                    where S.Output == Input {
        super.init(source:source, signalHz:signalHz, errorEstimator:errorEstimator, loopBandwidth:loopBandwidth)
    }
    
    override func process(_ x:Input, _ out:inout Output) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        out.removeAll()
        for v in x {
            let o = osc.next()!
            out.append(v*o)
            if let errorEstimator = errorEstimator {
                let e: Float = errorEstimator(v,o)
                //print("Mixer",v,o,e)
                adjust(e)
            }
        }
    }

}
