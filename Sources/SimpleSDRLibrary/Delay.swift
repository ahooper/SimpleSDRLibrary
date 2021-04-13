//
//  Delay.swift
//  
//
//  Created by Andy Hooper on 2021-04-10.
//

public class Delay<Samples:DSPSamples>:BufferedStage<Samples,Samples> {
    var buffer:Samples
    let P:Int

    public init<S:SourceProtocol>(source:S?, _ P:Int) where S.Output == Samples {
        precondition(P >= 0)
        self.P = P
        buffer = Samples(repeating:Samples.zero, count:P)
        super.init("Delay", source:source)
    }
    
    /*
     buff    x                    buff    out
     0 0 0 | 1 2 3 4 5 6 7 8 9 => 7 8 9 | 0 0 0 1 2 3 4 5 6
     0 0 0 | 1 2 => 0 1 2 | 0 0
     */
    
    override func process(_ x:Samples, _ out:inout Samples) {
        let inCount = x.count
        out.resize(inCount) // output same size as input
        if inCount == 0 { return }
        if inCount >= P {
            out.replaceSubrange(0..<P, with: buffer, 0..<P)
            out.replaceSubrange(P..<inCount, with: x, 0..<(inCount-P))
            buffer.replaceSubrange(0..<P, with:x, (inCount-P)..<inCount)
        } else {
            buffer.append(x)
            out.replaceSubrange(0..<inCount, with: buffer, 0..<inCount)
            buffer.removeSubrange(0..<inCount)
        }
    }

}
