/**
    Inochi2D SIMD Helpers

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.math.simd;
import inteli;

/**
    An identity 4-dimensional vector.
*/
static const __m128 IN_SIMD_IDENTITY = __m128([0, 0, 0, 1]);

/**
    An identity 8-dimensional vector.
*/
static const __m256 IN_AVX_IDENTITY = __m256([0, 0, 0, 1, 0, 0, 0, 1]);

public import inochi2d.core.math.simd.matrix;
public import inochi2d.core.math.simd.vector;
public import inochi2d.core.math.simd.mesh;