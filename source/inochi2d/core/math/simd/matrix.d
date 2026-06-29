/**
    Inochi2D Matrix SIMD Helpers

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.math.simd.matrix;
import numath;
version(Have_intelintrinsics) import inteli;

///**
//    Multiplies 2 4x4 matrices together with SIMD.

//    Params:
//        a = first matrix
//        b = second matrix

//    Returns:
//        The result of the 2 matrices multiplied together.
//*/
//mat4 simd_mul(mat4 a, mat4 b) @nogc nothrow pure {
//    mat4 c;
//    __m128 row1 = _mm_loadu_ps(&a.matrix[0][0]);
//    __m128 row2 = _mm_loadu_ps(&a.matrix[1][0]);
//    __m128 row3 = _mm_loadu_ps(&a.matrix[2][0]);
//    __m128 row4 = _mm_loadu_ps(&a.matrix[3][0]);
//    __m128 brod1;
//    __m128 brod2;
//    __m128 brod3;
//    __m128 brod4;
//    __m128 row;
//    static foreach (i; 0 .. 4) {
//        brod1 = _mm_set1_ps(b.matrix[i][0]);
//        brod2 = _mm_set1_ps(b.matrix[i][1]);
//        brod3 = _mm_set1_ps(b.matrix[i][2]);
//        brod4 = _mm_set1_ps(b.matrix[i][3]);
//        row = _mm_add_ps(
//                _mm_add_ps(
//                _mm_mul_ps(brod1, row1),
//                _mm_mul_ps(brod2, row2)),
//                _mm_add_ps(
//                _mm_mul_ps(brod3, row3),
//                _mm_mul_ps(brod4, row4)));
//        _mm_store_ps(&c.matrix[i][0], row);
//    }
//    return c;
//}