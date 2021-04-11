//
//  DSPSamples.swift
//  SDRplayFM
//
//  Created by Andy Hooper on 2020-03-17.
//  Copyright © 2020 Andy Hooper. All rights reserved.
//

import struct Accelerate.vecLib.vDSP.DSPComplex
//import struct Accelerate.vecLib.vDSP.DSPDoubleComplex
//import func Accelerate.vecLib.vDSP.vDSP_dotpr
//import struct Accelerate.vecLib.vDSP.vDSP_Length
import func CoreFoundation.cosf
import func CoreFoundation.sinf

public protocol DSPScalar:Numeric {
    init(_ real:Float)
    static func *(lhs:Self, rhs:Float) -> Self
    static func /(lhs:Self, rhs:Float) -> Self
    static func oscillator(_ phase:Float, _ level:Float) -> Self
        // TODO need a better name for this function
    var magnitude: Float { get }
}

extension Float:DSPScalar {
    public static func oscillator(_ phase:Float, _ level:Float) -> Self {
        cosf(phase) * level
    }
}

extension DSPComplex:DSPScalar {
    public static func oscillator(_ phase:Float, _ level:Float) -> Self {
        DSPComplex(cosf(phase) * level,
                   sinf(phase) * level)
    }
}

public protocol DSPSamples {
    associatedtype Element:DSPScalar
    static var zero:Element { get }
    static var nan:Element { get }
    
    init()
    init(repeating repeatedValue:Element, count:Int)
    init(_ array:[Element])
    var count:Int { get }
    var capacity:Int { get }
    subscript(index:Int)->Element { get set }
    mutating func append(_ newElement: Element)
    mutating func append(rangeOf X:Self, _ range:Range<Int>)
    mutating func append(_ X:Self)
    mutating func append<S:Sequence>(contentsOf newElements:S) where S.Element == Element
    mutating func replaceSubrange(_ r:Range<Int>, with:Self, _ w:Range<Int>)
    mutating func removeSubrange(_ r:Range<Int>)
    mutating func removeAll(keepingCapacity:Bool)
    mutating func reserveCapacity(_ minimumCapacity:Int)
    mutating func resize(_ newCount:Int)
    
    func weightedSum(at:Int, _ weights:[Float])->Element
}

public struct RealSamples:DSPSamples, CustomStringConvertible, CustomDebugStringConvertible  {
    
    public typealias Element = Float
    public static var zero:Element { get { Float.zero } }
    public static var nan:Element { get { Float.nan } }

    var real:[Element]
    public init() {
        real = [Element]()
    }
    public init(repeating repeatedValue:Element, count:Int) {
        real = [Element](repeating:repeatedValue, count:count)
    }
    public init(_ array:[Element]) {
        real = array
    }
    public var count:Int { get { real.count } }
    public var capacity:Int { get { real.capacity } }
    public subscript(index:Int)->Element {
        get { real[index] }
        set { real[index] = newValue }
    }
    public subscript(bounds:Range<Int>)->Slice<[Element]> {
        get { real[bounds] }
    }
    public mutating func append(_ newElement: Element) {
        real.append(newElement)
    }
    public mutating func append(rangeOf X:Self, _ range:Range<Int>) {
        real.append(contentsOf: X.real[range])
    }
    public mutating func append(_ X:Self) {
        append(rangeOf:X, 0..<X.count)
    }
    public mutating func append<S:Sequence>(contentsOf newElements:S)
                    where S.Element == Element {
        real.append(contentsOf:newElements)
    }
    public mutating func replaceSubrange(_ r:Range<Int>, with:Self, _ w:Range<Int>) {
        real.replaceSubrange(r, with:with[w])
    }
    public mutating func removeSubrange(_ r:Range<Int>) {
        real.replaceSubrange(r, with:EmptyCollection<Element>())
    }
    public mutating func removeAll(keepingCapacity:Bool=false) {
        real.removeAll(keepingCapacity:keepingCapacity)
    }
    public mutating func reserveCapacity(_ minimumCapacity:Int) {
        real.reserveCapacity(minimumCapacity)
    }
    public mutating func resize(_ newCount:Int) {
        if count > newCount {
            removeSubrange(newCount..<(count))
        } else if count < newCount {
            //if newCount > capacity { reserveCapacity(newCount) }
            append(contentsOf:repeatElement(Element.nan, count:newCount-count))
        }
    }

    public func weightedSum(at:Int, _ weights:[Float])->Element {
        var s:Element = Self.zero
        for i in 0..<weights.count {
            // compiler will use SIMD
            s += real[i+at] * weights[i]
            //print(" + ",real[i+at],"*",weights[i],separator:"",terminator:"")
        }
        //print(" =",s)
        //let wCount = weights.count
        //precondition(at+wCount <= real.count)
        //vDSP_dotpr(&real[at], 1, weights, 1, &s, vDSP_Length(wCount))
        //using vDSP_dotpr requires weightedSum be marked as mutating
        return s
    }
    
    public var description: String { real.description }
    public var debugDescription: String { real.debugDescription }
}

public struct ComplexSamples: DSPSamples, CustomStringConvertible/*TODO:, CustomDebugStringConvertible*/  {
    
    public typealias Element = DSPComplex
    public static var zero:Element { get { DSPComplex.zero } }
    public static var nan:Element { get { DSPComplex.nan } }

    private var real, imag:[Element.Element]
    public init() {
        real = [Element.Element]()
        imag = [Element.Element]()
    }
    public init(repeating repeatedValue:Element, count:Int) {
        real = [Element.Element](repeating:repeatedValue.real, count:count)
        imag = [Element.Element](repeating:repeatedValue.imag, count:count)
    }
    public init(_ array:[Element]) {
        real = array.map{$0.real}
        imag = array.map{$0.imag}
    }
    public var count:Int { get {
        //if real.count != imag.count { print("ComplexSamples count", real.count, imag.count) }
        return real.count
    } }
    public var capacity:Int { get {
        //if real.capacity != imag.capacity { print("ComplexSamples capacity", real.capacity, imag.capacity) }
        return min(real.capacity, imag.capacity)
    } }
    public subscript(index:Int)->Element {
        get { DSPComplex(real[index],imag[index]) }
        set { real[index] = newValue.real; imag[index] = newValue.imag }
    }
    public mutating func append(_ newElement: Element) {
        real.append(newElement.real)
        imag.append(newElement.imag)
    }
    public mutating func append(rangeOf X:Self, _ range:Range<Int>) {
        real.append(contentsOf: X.real[range])
        imag.append(contentsOf: X.imag[range])
assert(real.capacity==imag.capacity) //TODO: seeing inconsistent real&imag capacity increases
    }
    public mutating func append(_ X: Self) {
        append(rangeOf:X, 0..<X.count)
    }
    public mutating func append<S:Sequence>(contentsOf newElements:S) where S.Element == Element {
        //print("ComplexSamples append contentsOf",real.capacity,real.count,newElements.underestimatedCount)
assert(real.capacity==imag.capacity)
        let cap = capacity, c = count+newElements.underestimatedCount
        if c > cap { reserveCapacity(c) }
assert(real.capacity==imag.capacity)
        real.append(contentsOf:newElements.map{$0.real})
        imag.append(contentsOf:newElements.map{$0.imag})
assert(real.capacity==imag.capacity)
        if cap > capacity { print("ComplexSamples append contentsOf",real.count,cap,real.capacity,newElements.underestimatedCount) }
    }
    public mutating func append<S:Sequence>(real r:S, imag i:S) where S.Element == Element.Element {
        //print("ComplexSamples append real,imag",real.capacity,real.count,r.underestimatedCount)
        let cap = capacity
        real.append(contentsOf:r)
        imag.append(contentsOf:i)
        assert(real.count==imag.count)
        if cap > capacity { print("ComplexSamples append real,imag",real.count,cap,real.capacity,r.underestimatedCount) }
    }
    public mutating func replaceSubrange(_ r:Range<Int>, with:Self, _ w:Range<Int>) {
        real.replaceSubrange(r, with:with.real[w])
        imag.replaceSubrange(r, with:with.imag[w])
    }
    public mutating func removeSubrange(_ r:Range<Int>) {
        real.replaceSubrange(r, with:EmptyCollection<Float>())
        imag.replaceSubrange(r, with:EmptyCollection<Float>())
    }
    public mutating func removeAll(keepingCapacity:Bool=false) {
        real.removeAll(keepingCapacity:keepingCapacity)
        imag.removeAll(keepingCapacity:keepingCapacity)
     }
    public mutating func reserveCapacity(_ minimumCapacity:Int) {
assert(real.capacity==imag.capacity)
        real.reserveCapacity(minimumCapacity)
        imag.reserveCapacity(minimumCapacity)
assert(real.capacity==imag.capacity)
    }
    public mutating func resize(_ newCount:Int) {
        if count > newCount {
            removeSubrange(newCount..<(count))
        } else if count < newCount {
            //if newCount > capacity { reserveCapacity(newCount) }
            append(contentsOf:repeatElement(Element.nan, count:newCount-count))
        }
    }

    public func weightedSum(at:Int, _ weights:[Float])->Element {
        var s = Self.zero
        for i in 0..<weights.count {
            // compiler will use SIMD
            s.real += real[i+at] * weights[i]
            s.imag += imag[i+at] * weights[i]
            //print(" + ",real[i+at],",",imag[i+at],"*",weights[i],separator:"",terminator:"")
        }
        //print(" = ",s.real,",",s.imag,separator:"")
        //let wCount = weights.count
        //precondition(at+wCount <= real.count)
        //precondition(at+wCount <= imag.count)
        //vDSP_dotpr(&real[at], 1, weights, 1, &s.real, vDSP_Length(wCount))
        //vDSP_dotpr(&imag[at], 1, weights, 1, &s.imag, vDSP_Length(wCount))
        //using vDSP_dotpr requires weightedSum be marked as mutating
        return s
    }
    public var description: String {
        var result = "ComplexSamples(["
        for i in 0..<count {
            if i > 0 {
                result += ", "
            }
            debugPrint(DSPComplex(real[i],imag[i]), terminator: "", to: &result)
        }
        result += "])"
        return result
    }

    public func zip()->[Element] {
        Swift.zip(real,imag).map{Element($0.0,$0.1)}
    }
}

public struct NilSamples: DSPSamples  {
    public typealias Element = Float
    public static var zero:Element { get { Float.zero } }
    public static var nan:Element { get { Float.nan } }

    public init() {
    }
    public init(repeating repeatedValue:Element, count:Int) {
    }
    public init(_ array:[Element]) {
    }
    public var count:Int { get { 0 } }
    public var capacity:Int { get { 0 } }
    public subscript(index:Int)->Element {
        get { fatalError("NilSamples subscript is not possible") }
        set { fatalError("NilSamples subscript is not possible") }
    }
    public subscript(bounds:Range<Int>)->Slice<[Element]> {
        get { fatalError("NilSamples subscript is not possible") }
    }
    public mutating func append(_ newElement: Element) {
        fatalError("NilSamples append is not possible")
    }
    public mutating func append(rangeOf X:Self, _ range:Range<Int>) {
        fatalError("NilSamples append is not possible")
    }
    public mutating func append(_ X: NilSamples) {
        fatalError("NilSamples append is not possible")
    }
    public mutating func append<S:Sequence>(contentsOf newElements:S)
                    where S.Element == Element {
        fatalError("NilSamples append is not possible")
    }
    public mutating func replaceSubrange(_ r:Range<Int>, with:Self, _ w:Range<Int>) {
        fatalError("NilSamples replaceSubrange is not possible")
    }
    public mutating func removeSubrange(_ r:Range<Int>) {
    }
    public mutating func removeAll(keepingCapacity:Bool=false) {
    }
    public mutating func reserveCapacity(_ minimumCapacity:Int) {
    }
    public mutating func resize(_ newCount:Int) {
    }

    public func weightedSum(at:Int, _ weights:[Float])->Element {
        fatalError("NilSamples weightedSum is not possible")
    }
}
