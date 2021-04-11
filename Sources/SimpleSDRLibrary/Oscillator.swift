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

    public init(signalHz:Float=440, sampleHz:Int=48_000, level:Float=1.0) {
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
        let numSamples = Int(Float(sampleHz) / signalHz + 0.5)
        let w = 2.0 * Float32.pi * Float32(signalHz) / Float32(sampleHz)
        for i in 0..<numSamples {
            output.append(ComplexSamples.Element(cosf(Float32(i) * w) * level,
                                                 sinf(Float32(i) * w) * level))
        }
    }

    public init(signalHz:Float=440, sampleHz:Int=48_000, level:Float=1.0) {
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
        let numSamples = Int(Float(sampleHz) / signalHz + 0.5)
        let w = 2.0 * Float32.pi * Float32(signalHz) / Float32(sampleHz)
        for i in 0..<numSamples {
            output.append(Samples.Element.oscillator(Float32(i) * w, level))
        }
    }

    public init(signalHz:Float=440, sampleHz:Int=48_000, level:Float=1.0) {
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

