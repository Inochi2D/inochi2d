/**
    Inochi2D SIMD Helpers

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.math.simd;
import inmath.linalg;
import inmath.util;
import inteli;

/**
    Multiplies 2 4x4 matrices together with SIMD.

    Params:
        a = first matrix
        b = second matrix

    Returns:
        The result of the 2 matrices multiplied together.
*/
mat4 mulm4m4(mat4 a, mat4 b) @nogc nothrow pure {
    mat4 c;
    __m128 row1 = _mm_loadu_ps(&a.matrix[0][0]);
    __m128 row2 = _mm_loadu_ps(&a.matrix[1][0]);
    __m128 row3 = _mm_loadu_ps(&a.matrix[2][0]);
    __m128 row4 = _mm_loadu_ps(&a.matrix[3][0]);
    foreach(i; 0..4) {
        __m128 brod1 = _mm_set1_ps(b.matrix[i][0]);
        __m128 brod2 = _mm_set1_ps(b.matrix[i][1]);
        __m128 brod3 = _mm_set1_ps(b.matrix[i][2]);
        __m128 brod4 = _mm_set1_ps(b.matrix[i][3]);
        __m128 row = _mm_add_ps(
                    _mm_add_ps(
                        _mm_mul_ps(brod1, row1),
                        _mm_mul_ps(brod2, row2)),
                    _mm_add_ps(
                        _mm_mul_ps(brod3, row3),
                        _mm_mul_ps(brod4, row4)));
        _mm_store_ps(&c.matrix[i][0], row);
    }
    return c;
}

/**
    Multiplies a 2D vector with a 4D matrix.

    The 2D vector is promoted to a 4D vector,
    with the w coordinate set to 1.

    Params:
        a = the vector
        b = the matrix

    Returns:
        The result of multplying the vector with the matrix.
*/
VecT mulvm4(VecT)(VecT a, mat4 b) @nogc nothrow pure if (isVector!VecT) {
    __m128 vec = _mm_set_ps(1, 0, 0, 0);
    vec[0..VecT.dimension] = a.vector[0..$];
    
    __m128 result;
    foreach(row; 0..4) {

        __m128 acc = _mm_setzero_ps();
        __m128 mat = _mm_loadu_ps(&b.matrix[row][0]);
        acc = _mm_add_ps(acc, _mm_mul_ps(mat, vec));

        acc = _mm_hadd_ps(acc, acc);
        acc = _mm_hadd_ps(acc, acc);
        _mm_store_ss(&result[row], acc);
    }
    return (*cast(VecT*)&result);
}