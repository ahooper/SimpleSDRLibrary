//
//  SplitComplexOps.swift
//  SimpleSDR3
//
//  Created by Andy Hooper on 2020-02-07.
//  Copyright © 2020 Andy Hooper. All rights reserved.
//

import Accelerate.vecLib.vDSP

public enum SplitComplexOps {
    
// Three address operations are used to avoid storage allocation delays

    /// Adds two single-precision complex vectors.
    static func add(a: SplitComplex, b: SplitComplex, c: SplitComplex) {
        var aSplit = a.unsafePointers()
        var bSplit = b.unsafePointers()
        var cSplit = c.unsafePointers()
        let n = Swift.min(a.count, b.count)
        precondition(n <= c.count)
        vDSP_zvadd(&aSplit, 1,
                   &bSplit, 1,
                   &cSplit, 1,
                   vDSP_Length(n))
//        a.withUnsafePointers { (aSplit:DSPSplitComplex) -> Void in
//            b.withUnsafePointers { (bSplit:DSPSplitComplex) -> Void in
//                c.withUnsafePointers { (cSplit:DSPSplitComplex) -> Void in
//                    vDSP_zvadd(&aSplit, 1,
//                               &bSplit, 1,
//                               &cSplit, 1,
//                               vDSP_Length(n))
//                }
//            }
//        }
//        SplitComplex.with3UnsafePointers(a:a, b:b, c:c) { (aSplit:DSPSplitComplex, bSplit:DSPSplitComplex, cSplit:DSPSplitComplex) -> Void in
//            vDSP_zvadd(&aSplit, 1,
//                       &bSplit, 1,
//                       &cSplit, 1,
//                       vDSP_Length(n))
//        }
    }
    
    /// Subtracts two single-precision complex vectors.
    static func subtract(a: SplitComplex, b: SplitComplex, c: SplitComplex) {
        var aSplit = a.unsafePointers()
        var bSplit = b.unsafePointers()
        var cSplit = c.unsafePointers()
        let n = Swift.min(a.count, b.count)
        precondition(n <= c.count)
        vDSP_zvsub(&aSplit, 1,
                   &bSplit, 1,
                   &cSplit, 1,
                   vDSP_Length(n))
    }

    /// Multiplies a single-precision complex vector by the optionally conjugate of another single-precision complex vector.
    static func multiply(a: SplitComplex, aConjugate: Bool=false, b: SplitComplex, c: SplitComplex) {
        var aSplit = a.unsafePointers()
        var bSplit = b.unsafePointers()
        var cSplit = c.unsafePointers()
        let n = Swift.min(a.count, b.count)
        precondition(n <= c.count)
        vDSP_zvmul(&aSplit, 1,
                   &bSplit, 1,
                   &cSplit, 1,
                   vDSP_Length(n),
                   aConjugate ? -1 : +1)
    }
    
    /// Divides two complex single-precision vectors.
    static func divide(a: SplitComplex, b: SplitComplex, c: SplitComplex) {
        var aSplit = a.unsafePointers()
        var bSplit = b.unsafePointers()
        var cSplit = c.unsafePointers()
        let n = Swift.min(a.count, b.count)
        precondition(n <= c.count)
        // *** Note from zvdiv documentation that B comes before A! ***
        vDSP_zvdiv(&bSplit, 1,
                   &aSplit, 1,
                   &cSplit, 1,
                   vDSP_Length(n))
    }
    
    /// Calculates the dot product of two single-precision complex vectors.
    static func dotProduct(a: SplitComplex, b: SplitComplex, c: SplitComplex) {
        var aSplit = a.unsafePointers()
        var bSplit = b.unsafePointers()
        var cSplit = c.unsafePointers()
        let n = Swift.min(a.count, b.count)
        precondition(1 <= c.count)
        vDSP_zdotpr(&aSplit, 1,
                   &bSplit, 1,
                   &cSplit,
                   vDSP_Length(n))
    }

    /// Adds a single-precision complex vector to a single-precision real vector.
    static func add(a: SplitComplex, b: [Float], c: SplitComplex) {
        var aSplit = a.unsafePointers()
        var cSplit = c.unsafePointers()
        let n = Swift.min(a.count, b.count)
        precondition(n <= c.count)
        vDSP_zrvadd(&aSplit, 1,
                   b, 1,
                   &cSplit, 1,
                   vDSP_Length(n))
    }
    
    /// Subtracts a single-precision real vector from a single-precision complex vector.
    static func subtract(a: SplitComplex, b: [Float], c: SplitComplex) {
        var aSplit = a.unsafePointers()
        var cSplit = c.unsafePointers()
        let n = Swift.min(a.count, b.count)
        precondition(n <= c.count)
        vDSP_zrvsub(&aSplit, 1,
                   b, 1,
                   &cSplit, 1,
                   vDSP_Length(n))
    }

    /// Multiplies a single-precision complex vector by a single-precision real vector.
    static func multiply(a: SplitComplex, b: [Float], c: SplitComplex) {
        var aSplit = a.unsafePointers()
        var cSplit = c.unsafePointers()
        let n = Swift.min(a.count, b.count)
        precondition(n <= c.count)
        vDSP_zrvmul(&aSplit, 1,
                   b, 1,
                   &cSplit, 1,
                   vDSP_Length(n))
    }
    
    /// Divides a single-precision complex vector by a single-precision real vector.
    static func divide(a: SplitComplex, b: [Float], c: SplitComplex) {
        var aSplit = a.unsafePointers()
        var cSplit = c.unsafePointers()
        let n = Swift.min(a.count, b.count)
        precondition(n <= c.count)
        vDSP_zrvdiv(&aSplit, 1,
                   b, 1,
                   &cSplit, 1,
                   vDSP_Length(n))
    }
    
    /// Calculates the dot product of single-precision complex and real vectors.
    static func dotProduct(a: SplitComplex, b: [Float], c: SplitComplex) {
        var aSplit = a.unsafePointers()
        var cSplit = c.unsafePointers()
        let n = Swift.min(a.count, b.count)
        precondition(1 <= c.count)
        vDSP_zrdotpr(&aSplit, 1,
                   b, 1,
                   &cSplit,
                   vDSP_Length(n))
    }

    /// Performs convolution on two complex single-precision vectors.
    /// - Parameter a: Complex single-precision input signal vector. The length of this vector must be at least `N + P - 1`, where `N` is the length of the output vector `c`, and `P` is the length of the filter vector `f`.
    /// - Parameter f: Complex single-precision filter vector.
    /// - Parameter c: Complex single-precision output signal vector.
    static func convolve(a: SplitComplex, f: SplitComplex, c: SplitComplex) {
        // vDSP_zconv requirement: The length of the A vector must be at least N + P - 1.
        // with local names and exact sizing: a.count = c.count + p - 1
        // Invert this to get the count to be written: a.count - p + 1 = n
        let p = f.count
        let n = a.count - p + 1
        precondition(n <= c.count)
        var aSplit = a.unsafePointers()
        var fLast = f.unsafePointers(offset: p-1)
        var cSplit = c.unsafePointers()
        vDSP_zconv(/*A*/&aSplit, 1,
                   /*F*/&fLast, -1, // convolution if stride negative
                   /*C*/&cSplit, 1,
                   /*N*/vDSP_Length(n),
                   /*P*/vDSP_Length(p))
    }
    
    /// Performs correlation on two complex single-precision vectors.
    /// - Parameter a: Complex single-precision input signal vector. The length of this vector must be at least `N + P - 1`, where `N` is the length of the output vector `c`, and `P` is the length of the filter vector `f`.
    /// - Parameter f: Complex single-precision filter vector.
    /// - Parameter c: Complex single-precision output signal vector.
    static func correlate(a: SplitComplex, f: SplitComplex, c: SplitComplex) {
        // vDSP_zconv requirement: The length of the A vector must be at least N + P - 1.
        // with local names and exact sizing: a.count = c.count + p - 1
        // Invert this to get the count to be written: a.count - p + 1 = n
        let p = f.count
        let n = a.count - p + 1
        precondition(n <= c.count)
        var aSplit = a.unsafePointers()
        var fSplit = f.unsafePointers()
        var cSplit = c.unsafePointers()
        vDSP_zconv(/*A*/&aSplit, 1,
                   /*F*/&fSplit, 1, // correlation if stride positive
                   /*C*/&cSplit, 1,
                   /*N*/vDSP_Length(n),
                   /*P*/vDSP_Length(p))
    }
    
    /**
     Performs complex-real single-precision FIR filtering with decimation and antialiasing.
     - Parameter a: Single-precision complex input vector. The size of `a` must be at least
     `df * (N-1) + P`, where `N` is the length of the output vector `c` and
     `P` is the  length of the filter vector `f`.
     - Parameter df: Decimation factor.
     - Parameter f: Single-precision real filter vector.
     - Parameter c: Single-precision complex output vector.
     */
    static func decimate(a: SplitComplex, df: Int, f: [Float], c: SplitComplex) {
        // vDSP_zrdesamp requirement: The length of the A vector must be at least DF * (N - 1) + P.
        // with local names and exact sizing: a.count = df * (c.count - 1) + p
        // Invert this to get the count to be written: (a.count - p) / df + 1 = n
        let p = f.count
        let n = (a.count - p) / df + 1
        //print("decimate",a.count,df,p,n,c.count)
        precondition(n <= c.count)
        var aSplit = a.unsafePointers()
        var cSplit = c.unsafePointers()
        vDSP_zrdesamp(/*A*/&aSplit,
                      /*DF*/df,
                      /*F*/f,
                      /*C*/&cSplit,
                      /*N*/vDSP_Length(n),
                      /*P*/vDSP_Length(p))
    }
    
    /// Calculates the single-precision elementwise phase values, in radians, of the supplied complex vector.
    /// - Parameter a: Single-precision complex input vector.
    /// - Parameter c: Single-precision real output vector.
    static func phase(a: SplitComplex, c: inout [Float]) {
        let n = a.count
        precondition(n <= c.count)
        var aSplit = a.unsafePointers()
        vDSP_zvphas(/*A*/&aSplit, 1,
                    /*C*/&c, 1,
                    /*N*/vDSP_Length(n))
    }
    
    /// Complex vector absolute values.
    /// - Parameter a: Single-precision complex input vector.
    /// - Parameter c: Single-precision real output vector.
    static func absolute(a: SplitComplex, c: inout [Float]) {
        let n = a.count
        precondition(n <= c.count)
        var aSplit = a.unsafePointers()
        vDSP_zvabs(/*A*/&aSplit, 1,
                   /*C*/&c, 1,
                   /*N*/vDSP_Length(n))
    }

    /*
    /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/Accelerate.framework/Versions/A/Frameworks/vecLib.framework/Versions/A/Headers/vDSP.h
    ✓     538:extern void vDSP_ztoc(
    ✓    2188:extern void vDSP_zconv(
         2412:extern void vDSP_zmma(
         2456:extern void vDSP_zmms(
         2499:extern void vDSP_zvmmaa(
         2540:extern void vDSP_zmsm(
         2584:extern void vDSP_zmmul(
    ✓    2649:extern void vDSP_zvadd(
    ✓    2667:extern void vDSP_zrvadd(
    ✓    2713:extern void vDSP_zvsub(
    ✓    2759:extern void vDSP_zrvmul(
    ✓    2814:extern void vDSP_zvdiv(
    ✓    2832:extern void vDSP_zrvdiv(
    ✓    2976:extern void vDSP_zdotpr(
    ✓    2992:extern void vDSP_zrdotpr(
         3071:extern void vDSP_zvma(
    ✓    3103:extern void vDSP_zvmul(
         3140:extern void vDSP_zidotpr(
         3165:extern void vDSP_zvcma(
    ✓    3197:extern void vDSP_zrvsub(
    ✓    3270:extern void vDSP_zvabs(
         3331:extern void vDSP_zvfill(
         3421:extern void vDSP_zaspec(
         3473:extern void vDSP_zcoher(
    ✓    3515:extern void vDSP_zrdesamp(
         3544:extern void vDSP_ztrans(
         3568:extern void vDSP_zcspec(
         3592:extern void vDSP_zvcmul(
         3620:extern void vDSP_zvconj(
         3644:extern void vDSP_zvzsml(
         3670:extern void vDSP_zvmags(
         3694:extern void vDSP_zvmgsa(
         3722:extern void vDSP_zvmov(
         3746:extern void vDSP_zvneg(
    ✓    3770:extern void vDSP_zvphas(
         3794:extern void vDSP_zvsma(
    */

    static func DFT_Execute(_ dft: vDSP_DFT_Setup, _ input: SplitComplex, _ output: SplitComplex) {
        let iSplit = input.unsafePointers()
        let oSplit = output.unsafePointers()
        vDSP_DFT_Execute(dft,
                         iSplit.realp, iSplit.imagp,
                         oSplit.realp, oSplit.imagp)
    }

}
