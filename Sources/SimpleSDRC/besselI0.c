//
//  besselI0.c
//  SimpleSDR
//
//  Excerpt from https://github.com/kapteyn-astro/gipsy/blob/master/sub/bessel.c
//  Part of GIPSY https://www.astro.rug.nl/~gipsy/
//  Copyright (c) 1998 Kapteyn Institute Groningen
//

#include <math.h>
#include "besselI0.h"

/// Evaluate modified Bessel function In(x) and n=0.
// This function remains in C since Swift 5.1 chokes on the nested expressions.
double bessi0( double x )
{
    double ax, ans;
    double y;

    ax = fabs(x);
    if (ax < 3.75) {
        (void)(y = x/3.75), y = y*y;
        ans = 1.0 + y*(3.5156229 + y*(3.0899424 + y*(1.2067492
                         + y*(0.2659732 + y*(0.360768e-1 + y*0.45813e-2)))));
    } else {
        y = 3.75/ax;
        ans = (exp(ax)/sqrt(ax)) * (0.39894228 + y*(0.1328592e-1
                                    + y*(0.225319e-2 + y*(-0.157565e-2 + y*(0.916281e-2
                                    + y*(-0.2057706e-1 + y*(0.2635537e-1 + y*(-0.1647633e-1
                                    + y*0.392377e-2))))))));
    }
    return ans;
}
