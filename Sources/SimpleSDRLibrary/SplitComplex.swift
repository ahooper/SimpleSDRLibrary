//
//  SplitComplex.swift
//  SimpleSDR3
//
//  Created by Andy Hooper on 2019-12-15.
//  Copyright © 2019 Andy Hooper. All rights reserved.
//

import struct Accelerate.vecLib.vDSP.DSPComplex
import struct Accelerate.vecLib.vDSP.DSPSplitComplex

public class SplitComplex {
    // not a struct, so pointers to the real and imaginary components can be made
    // subset of RangeReplaceableCollection, MutableCollection
    var real, imag:[Float]

    static let zero = DSPComplex(Float.zero,Float.zero)
    static let nan = DSPComplex(Float.nan,Float.nan)

    required init() {
        real = [Float]()
        imag = [Float]()
    }

    public init(real r:[Float], imag i:[Float]) {
        precondition(r.count == i.count)
        real = r
        imag = i
    }

    public init(_ c:[DSPComplex]) {
        real = [Float](c.map{$0.real})
        imag = [Float](c.map{$0.imag})
    }

    required init(repeating:DSPComplex, count:Int) {
        real = [Float](repeating:repeating.real, count:count)
        imag = [Float](repeating:repeating.imag, count:count)
    }

    public var count:Int {
        return real.count
    }
    
    public var capacity:Int {
        return real.capacity
    }

    public subscript(index:Int)->DSPComplex {
        // bounds will be checked on each component access
        get {
            DSPComplex(real[index], imag[index])
        }
        set(newValue) {
            real[index] = newValue.real
            imag[index] = newValue.imag
        }
    }

    public func reserveCapacity(_ minimumCapacity:Int) {
        real.reserveCapacity(minimumCapacity)
        imag.reserveCapacity(minimumCapacity)
    }

    public func append(contentsOf X:SplitComplex) {
        assert(real.count == imag.count, "real.count != imag.count")
        real.append(contentsOf:X.real)
        imag.append(contentsOf:X.imag)
    }

    public func append(contentsOf X:SplitComplex, range:Range<Int>) {
        assert(real.count == imag.count, "real.count != imag.count")
        real.append(contentsOf:X.real[range])
        imag.append(contentsOf:X.imag[range])
    }
/*
    func append<S>(contentsOf newElements: __owned S)
                where S:Sequence, DSPComplex==S.Element {
        real.append(contentsOf:newElements.map{$0.real})
        imag.append(contentsOf:newElements.map{$0.imag})
    }
*/
    public func append(real r:Float, imag i:Float) {
        assert(real.count == imag.count, "real.count != imag.count")
        real.append(r)
        imag.append(i)
    }

    public func append(_ X:DSPComplex) {
        assert(real.count == imag.count, "real.count != imag.count")
        real.append(X.real)
        imag.append(X.imag)
    }

    public func removeSubrange(_ bounds:Range<Int>) {
        assert(real.count == imag.count, "real.count != imag.count")
        real.removeSubrange(bounds)
        imag.removeSubrange(bounds)
    }
    
    public func removeAll(keepingCapacity:Bool=false) {
        assert(real.count == imag.count, "real.count != imag.count")
        real.removeAll(keepingCapacity:true)
        imag.removeAll(keepingCapacity:true)
    }

    public func replaceSubrange(_ r:Range<Int>, with:SplitComplex, _ w:Range<Int>) {
        assert(real.count == imag.count,
               "real.count(\(real.count)) != imag.count(\(imag.count)) ")
        assert(real.indices == imag.indices,
               "real.indices(\(real.indices)) != imag.indices(\(imag.indices))")
        assert(real.startIndex <= r.startIndex && r.endIndex <= real.endIndex,
               "range(\(r)) not within (\(real.startIndex)..<\(real.endIndex))")
        assert(imag.startIndex <= r.startIndex && r.endIndex <= imag.endIndex,
               "range(\(r)) not within (\(imag.startIndex)..<\(imag.endIndex))")
        assert(with.real.count == with.imag.count,
               "with.real.count(\(with.real.count)) != with.imag.count(\(with.imag.count))")
        assert(with.real.indices == with.imag.indices,
               "with.real.indices(\(with.real.indices)) != with.imag.indices(\(with.imag.indices))")
        assert(with.real.startIndex <= w.startIndex && w.endIndex <= with.real.endIndex,
               "range(\(w)) not within (\(with.real.startIndex)..<\(with.real.endIndex))")
        assert(with.imag.startIndex <= w.startIndex && w.endIndex <= with.imag.endIndex,
               "range(\(w)) not within (\(with.imag.startIndex)..<\(with.imag.endIndex))")
        real.replaceSubrange(r, with:with.real[w])
        imag.replaceSubrange(r, with:with.imag[w])
    }

    public func unsafePointers()->DSPSplitComplex {
        assert(real.count == imag.count, "real.count != imag.count")
        // expression creates a temporary pointer that outlives the call
        return DSPSplitComplex(realp:&real, imagp:&imag)
    }
    
    public func unsafePointers(offset:Int)->DSPSplitComplex {
        assert(real.count == imag.count, "real.count != imag.count")
        assert(real.indices.contains(offset), "Offset out of range")
        // expression creates a temporary pointer that outlives the call
        return DSPSplitComplex(realp:&real[offset], imagp:&imag[offset])
    }

    // TODO Following have not been tested
    
    func withUnsafePointers<R>(
      _ body: (DSPSplitComplex) throws -> R
    ) rethrows -> R {
        assert(real.count == imag.count, "real.count != imag.count")
        return try body(DSPSplitComplex(realp:&real, imagp:&imag))
    }
    
    static func with3UnsafePointers<R>(
        a:inout SplitComplex, b:inout SplitComplex, c:inout SplitComplex,
      _ body: (DSPSplitComplex,DSPSplitComplex,DSPSplitComplex) throws -> R
    ) rethrows -> R {
        assert(a.real.count == a.imag.count, "real.count != imag.count")
        assert(b.real.count == b.imag.count, "real.count != imag.count")
        assert(c.real.count == c.imag.count, "real.count != imag.count")
        return try body(DSPSplitComplex(realp:&a.real, imagp:&a.imag),
                        DSPSplitComplex(realp:&b.real, imagp:&b.imag),
                        DSPSplitComplex(realp:&c.real, imagp:&c.imag))
    }

    func withUnsafePointers<R>(
        offset:Int,
      _ body: (DSPSplitComplex) throws -> R
    ) rethrows -> R {
        assert(real.count == imag.count, "real.count != imag.count")
        assert(real.indices.contains(offset), "Offset out of range")
        return try body(DSPSplitComplex(realp:&real[offset], imagp:&imag[offset]))
    }
}
