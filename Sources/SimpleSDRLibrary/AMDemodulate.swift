//
//  AMDemodulate.swift
//  
//
//  Created by Andy Hooper on 2020-05-05.
//

public class AMDemodulate:BufferedStage<ComplexSamples,RealSamples> {
    let factor:Float
    
    public init<S:SourceProtocol>(_ name:String,
                                  source:S?,
                                  factor:Float=1) where S.Output == Input {
        self.factor = factor
        super.init(name, source:source)
    }
}

public class AMEnvDemodulate:AMDemodulate {
    
    public init<S:SourceProtocol>(source:S?,
                                  factor:Float=1) where S.Output == Input {
        super.init("AMEnvDemodulate", source:source, factor:factor)
    }
    
    override func process(_ x:ComplexSamples, _ out:inout RealSamples) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        for i in 0..<inCount {
            // envelope
            out[i] = x[i].modulus() / factor
            //print(String(format:"%d %.3f", i, out[i]))
        }
    }
}

public class AMSyncDemodulate:AMDemodulate {
    let osc:PLL

    public init<S:SourceProtocol>(source:S?,
                                  factor:Float=1) where S.Output == Input {
        osc = PLL(source: source, signalHz: 0, errorEstimator: { x,o in
            (x * o.conjugate()).argument()
        })
        super.init("AMSyncDemodulate", source:source, factor:factor)
    }
    
    override func process(_ x:ComplexSamples, _ out:inout RealSamples) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        assert(osc.produceBuffer.count == inCount)
        for i in 0..<inCount {
            out[i] = (x[i] * osc.produceBuffer[i].conjugate()).magnitude / factor
        }
    }
}

public class AMCostasDemodulate:AMDemodulate {
    let osc:PLL

    public init<S:SourceProtocol>(source:S?,
                                  factor:Float=1) where S.Output == Input {
        osc = PLL(source: source, signalHz: 0, errorEstimator: { x,o in
            let v = x * o.conjugate()
            return v.imag * (v.real > 0 ? 1 : -1)
        })
        super.init("AMCostasDemodulate", source:source, factor:factor)
    }
    
    override func process(_ x:ComplexSamples, _ out:inout RealSamples) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        assert(osc.produceBuffer.count == inCount)
        for i in 0..<inCount {
            out[i] = (x[i] * osc.produceBuffer[i].conjugate()).real / factor
        }
    }
}
