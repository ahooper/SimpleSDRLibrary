//
//  BufferedStage.swift
//  SimpleSDR3
//
//  Created by Andy Hooper on 2019-12-16.
//  Copyright © 2019 Andy Hooper. All rights reserved.
//

import func CoreFoundation.usleep
import class Foundation.Thread
import class Foundation.NSCondition

//  http://chris.eidhof.nl/post/type-erasers-in-swift/
//  https://academy.realm.io/posts/type-erased-wrappers-in-swift/
//  https://www.youtube.com/watch?v=XWoNjiSPqI8&feature=youtu.be
//  swift-swift-5.1.1-RELEASE/stdlib/public/core/ExistentialCollection.swift.gyb

public protocol SinkProtocol {
    associatedtype Input
    func process(_ input:Input)
}

public class SinkBox<Input>: SinkProtocol {
    public func process(_ input:Input) {
        fatalError("SinkBox process(input:) method must be overridden.")
    }
}

public class SinkBoxHelper<S:SinkProtocol>: SinkBox<S.Input> {
    var sink: S
    public init(_ sink:S) {
        self.sink = sink
    }
    override public func process(_ input:Input) {
        return sink.process(input)
    }
}

public protocol SourceProtocol {
    associatedtype Output
    /// Add a sink stage to be called to process output from this stage.
    func addSink<S:SinkProtocol>(_ sink:S, asThread:Bool)
                where S.Input == Output
    /// Get the sampling frequency this stage is processing.
    func sampleFrequency()-> Double
    /// Read the next block from the source. Return nil if exiting.
    func read()-> Output?
    func hasFinished()-> Bool
    func getName()-> String
}

public class SourceBox<Output>: SourceProtocol {
    /// Add a sink stage to be called to process output from this stage.
    public func addSink<S:SinkProtocol>(_ sink:S, asThread:Bool)
                where S.Input == Output {
        fatalError("SourceBox addSink() method must be overridden.")
    }
    /// Get the sampling frequency this stage is processing.
    public func sampleFrequency()-> Double {
        fatalError("Source sampleFrequency() method must be overridden.")
    }
    /// Read the next block from the source. Return nil if exiting.
    public func read()-> Output? {
        fatalError("SourceBox read() method must be overridden.")
    }
    public func hasFinished()-> Bool {
        return false
    }
    public func getName()-> String {
        return "NOT A THREAD!"
    }
    
    public static func NilReal()->SourceBox<RealSamples>? { nil }
    public static func NilComplex()->SourceBox<ComplexSamples>? { nil }
}

class SourceBoxHelper<S:SourceProtocol>: SourceBox<S.Output> {
    var source: S
    init(_ source: S) {
        self.source = source
    }
    /// Add a sink stage to be called to process output from this stage.
    override func addSink<S:SinkProtocol>(_ sink:S, asThread:Bool)
                where S.Input == Output {
        source.addSink(sink, asThread:asThread)
    }
    /// Get the sampling frequency this stage is processing.
    override func sampleFrequency()-> Double {
        return source.sampleFrequency()
    }
    /// Read the next block from the source. Return nil if exiting.
    override func read()-> Output? {
        return source.read()
    }
    override func hasFinished()-> Bool {
        return source.hasFinished()
    }
    override func getName()-> String {
        return source.getName()
    }
}

open class Sink<Input>: Thread, SinkProtocol
                where Input:DSPSamples {
    public var source:SourceBox<Input>?
    public let isThread:Bool
    
    public init<S:SourceProtocol>(_ name:String, source:S?, asThread:Bool=false)
                    where S.Output == Input {
        isThread = asThread
        super.init()
        self.name = name
        if let source = source {
            setSource(source)
        }
        if asThread { start() }
    }
    
    public init(_ name:String, asThread:Bool=false) {
        isThread = asThread
        super.init()
        self.name = name
        if asThread { start() }
    }

    open func setSource<S:SourceProtocol>(_ source:S) where S.Output == Input {
        self.source = SourceBoxHelper(source)
        source.addSink(self, asThread:isThread)
    }

    open func process(_ x:Input) {
        fatalError("Sink process() method must be overridden.")
    }

    /// The main processing loop for a Thread stage.
    override public func main() {
        print(className, "thread", name ?? "unknown", "main")
        self.qualityOfService = .userInteractive

        while source == nil && !isCancelled {
            // wait for source to be connected
            usleep(500_000)
        }
        while !isCancelled {
            if let read = source?.read() {
                //print(name ?? "unknown", read.count)
                process(read)
            } else {
                break
            }
        }
        print(name ?? "unknown", "main exit")
    }

}

// BufferedStage can be started as a Thread, in which case main() will read()
// from the source. If it is not started, process(input:) can be called
// synchronously by the source and it will push output to its sinks.

open class BufferedStage<Input,Output>: Sink<Input>, SourceProtocol
            where Input:DSPSamples, Output:DSPSamples {
    var outputBuffer = Output(),    // buffer currently being written - the producer thread has
                                    // exclusive access to this buffer until it calls produce()
        produceBuffer = Output()    // buffer currently being consumed by sinks - the consumer
                                    // threads have shared read access to this buffer until
                                    // they call read()
    var directSinks = [SinkBox<Output>]()
 
    /// Add a sink to receive output of this stage.
    public func addSink<S>(_ sink: S, asThread: Bool) where S : SinkProtocol, Output == S.Input {
        if asThread {
            barrier.lock()
            threadCount += 1
            barrier.unlock()
        } else {
            directSinks.append(SinkBoxHelper(sink))
        }
    }

    /// Get the sampling frequency this stage is processing.
    public func sampleFrequency()-> Double {
        if let source = source { return source.sampleFrequency() }
        else { return Double.nan }
    }
    
    var barrier = NSCondition(), // locking for single producer, multiple consumers
        threadCount = 0, // number of sink threads linked
        readCount = 0, // number of sink threads in read(), i.e., done processing previous
        cycle = 0
    //  https://github.com/isotes/pthread-barrier-macos/blob/master/src/pthread_barrier.c
    //  https://github.com/boostorg/fiber/blob/develop/src/barrier.cpp
    
    /// Provide the current output buffer to the sinks for processing.
    // subLock, if used, is passed in to ensure locking order is maintained
    public func produce(clear:Bool=false, subLock:NSCondition?=nil) {
        //print(name ?? "unknown", "produce", outputIndex, buffers[outputIndex].count)
        barrier.lock()
            // Wait until all sinks are ready for a new buffer, and previous buffer processing has completed.
            threadWaitTime.start()
            while readCount < threadCount {
                barrier.wait()
            }
            threadWaitTime.stop()
            if clear { produceBuffer.removeAll(keepingCapacity:true) }
            cycle += 1
            subLock?.lock()
                swap(&outputBuffer, &produceBuffer)
            subLock?.unlock()
            readCount = 0
            barrier.broadcast() // tell parallel sink readers to process new data
        barrier.unlock()
        
        //print(name ?? "unknown","process",produceBuffer.count)
        sinkProcessTime.start()
        for s in directSinks {
            s.process(produceBuffer)
        }
        sinkProcessTime.stop()
    }
    var threadWaitCount = 0
    public var threadWaitTime = TimeReport(subjectName:"Thread wait")
    public var sinkProcessTime = TimeReport(subjectName:"Sink process")

    /// Read the next block from the source. Return nil if exiting.
    public func read()->Output? {
        barrier.lock()
            let c = cycle
            //print((Thread.current.name ?? "unknown"), "done", (name ?? "unknown"), c)
            readCount += 1
            barrier.broadcast()
            while c == cycle {
                if let source = source,
                       source.hasFinished() {
                    // unwinding
                    barrier.unlock()
                    print(name ?? "unknown", source.getName(), "hasFinished")
                    return nil
                }
                barrier.wait()
            }
        barrier.unlock()
        //print((Thread.current.name ?? "unknown"), "process", (name ?? "unknown"), cycle, produceBuffer.count)
        return produceBuffer
    }

    public override func process(_ input:Input) {
        process(input, &outputBuffer)
        produce()
    }

    func process(_ x:Input, _ out:inout Output) {
        fatalError("BufferedStage process(:,:) method must be overridden.")
    }
    
    public func hasFinished() -> Bool {
        return isExecuting
    }
    
    public func getName() -> String {
        return /*Thread*/name ?? "unknown"
    }

}
