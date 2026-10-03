/**
    Inochi2D Vector SIMD Helpers

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.math.simd.vector;
import inochi2d.core.math.simd;
import numem.core.math;
import numath;
import inteli;

/**
    Multiplies all of the vertices in a mesh with a given matrix.
    For larger meshes this operation is done with SIMD.

    Params:
        mesh = The mesh to apply the transformation of the matrix to.
        matrix = The matrix to apply.
*/
void simd_mul(ref vec2[] mesh, mat4 matrix) @nogc nothrow {

    // NOTE:    SSE version of the algorithm.
    //          This algorithm loads 128 bits of mesh data at a time, then deforms it.
    //          Value is stored unaligned to memory.
    //          
    // TODO:    Add aligned version?
    static if (!SSESizedVectorsAreEmulated) {

        // Load matrix into SIMD variables.
        __m128 r0 = _mm_loadu_ps(&matrix.matrix[0][0]);
        __m128 r1 = _mm_loadu_ps(&matrix.matrix[1][0]);

        // SIMD version
        size_t i = 0;
        for (; i < nu_aligndown(mesh.length, 2); i += 2) {

            // Load vectors into SIMD variables.
            __m128 xy01 = _mm_loadl_pi(IN_SIMD_IDENTITY, cast(const(__m64)*)mesh[i].ptr);
            __m128 zw01 = _mm_loadl_pi(IN_SIMD_IDENTITY, cast(const(__m64)*)mesh[i + 1].ptr);

            // Perform matrix multiplication
            __m128 x = _mm_mul_ps(xy01, r0);
            __m128 y = _mm_mul_ps(xy01, r1);
            __m128 z = _mm_mul_ps(zw01, r0);
            __m128 w = _mm_mul_ps(zw01, r1);
            __m128 xy = _mm_hadd_ps(x, y);
            __m128 zw = _mm_hadd_ps(z, w);
            __m128 xyzw = _mm_hadd_ps(xy, zw);

            // Store 2 multiplied elements at once to mesh.
            _mm_storeu_ps(cast(float*)mesh[i].ptr, xyzw);
        }

        // Tail iteration to finalize the multiplication
        if (i < mesh.length) {
            __m128 xy01 = _mm_loadl_pi(IN_SIMD_IDENTITY, cast(const(__m64)*)mesh[i].ptr);
            __m128 x = _mm_mul_ps(xy01, r0);
            __m128 y = _mm_mul_ps(xy01, r1);
            __m128 xy = _mm_hadd_ps(_mm_hadd_ps(x, y), _mm_hadd_ps(x, y));
            _mm_storel_pi(cast(__m64*)mesh[i].ptr, xy);
        }
    } else {

        // Non-SIMD version
        foreach (ref vertex; mesh) {
            vertex = (vec4(vertex.x, vertex.y, 0, 1) * matrix).xy;
        }
    }
}

@("simd_mul")
unittest {
    mat4 testMatrix = mat4.translation(1.0, 0.0, 0.0);
    vec2[] testArray = new vec2[10_001];
    testArray[] = vec2(1.0, 1.0);

    simd_mul(testArray, testMatrix);
    foreach (i, value; testArray) {
        assert(value == vec2(2.0, 1.0));
    }
}

/**
    Offsets all of the coordinates in the given mesh with the given offset.
    For larger meshes, the offset is done with SIMD.

    Params:
        mesh =      The mesh to offset.
        offset =    The offset to perform
*/
void simd_offset(ref vec2[] mesh, vec2 offset) @nogc nothrow {
    static if (!SSESizedVectorsAreEmulated) {

        // Offset loaded from variable.
        __m128 m_offset = _mm_set_ps(offset.y, offset.x, offset.y, offset.x);

        // SIMD version
        size_t i = 0;
        for (; i < nu_aligndown(mesh.length, 2); i += 2) {
            _mm_storeu_ps(
                    cast(float*)mesh[i].ptr,
                    _mm_add_ps(
                    _mm_loadu_ps(cast(float*)mesh[i].ptr),
                    m_offset
            )
            );
        }

        // Tail iteration to finalize the offset
        if (i < mesh.length) {
            _mm_storel_pi(
                    cast(__m64*)mesh[i].ptr,
                    _mm_add_ps(
                    _mm_loadl_pi(
                    IN_SIMD_IDENTITY,
                    cast(const(__m64)*)&mesh[i]
                    ),
                    m_offset
            )
            );
        }
    } else {

        // Non-SIMD version
        foreach (i; 0 .. mesh.length) {
            mesh[i] += offset;
        }
    }
}

@("simd_offset")
unittest {
    vec2[] array1 = new vec2[10_001];
    array1[] = vec2(0);

    simd_offset(array1, vec2(1, 1));
    foreach (i, value; array1) {
        assert(value == vec2(1.0, 1.0));
    }
}

/**
    Multiplies all vertices in a given mesh with the given weights.

    Params:
        mesh = The mesh to scale based on weight.
        weights = The weights to scale by.
*/
void simd_mul_weight(ref vec2[] mesh, ref float[] weights) @nogc nothrow {
    size_t w_length = nu_min(mesh.length, weights.length);

    // NOTE:    SSE version of the algorithm.
    //          This algorithm loads 128 bits of mesh data at a time, then deforms it.
    //          Value is stored unaligned to memory.
    //          
    // TODO:    Add aligned version?
    __gshared const __m128i WEIGHT_OFFSETS = __m128i([0, 0, 1, 1]);
    static if (!SSESizedVectorsAreEmulated) {

        // SIMD version
        size_t i = 0;
        for (; i < nu_aligndown(w_length, 2); i += 2) {

            // Load weights and vector
            __m128 w0011 = _mm_i32gather_ps!(4)(cast(const(float)*)&weights[i], WEIGHT_OFFSETS);
            __m128 xyzw = _mm_load_ps(cast(const(float)*)&mesh[i]);

            // Perform matrix multiplication and
            // Store 2 multiplied elements at once to mesh.
            __m128 weighted = _mm_mul_ps(xyzw, w0011);
            _mm_storeu_ps(cast(float*)mesh[i].ptr, weighted);

        }

        // Tail iteration to finalize the multiplication
        if (i < w_length) {
            mesh[i] = mesh[i] * weights[i];
        }
    } else {

        // Non-SIMD version
        foreach (i; 0 .. w_length) {
            mesh[i] = mesh[i] * weights[i];
        }
    }
}

@("simd_mul_weight")
unittest {
    vec2[] array1 = new vec2[10_001];
    array1[] = vec2(0.5);

    float[] weights = new float[10_001];
    weights[] = 0.5;

    simd_mul_weight(array1, weights);
    foreach (i, value; array1) {
        assert(value == vec2(0.25, 0.25));
    }
}

/**
    Multiplies all vertices in a given mesh with the given weights.

    Params:
        buffer = The buffer to scale based on weight.
        weight = The weight to scale by.
*/
void simd_scale(float[] buffer, float weight) @nogc nothrow {

    // NOTE:    SSE version of the algorithm.
    //          This algorithm loads 128 bits of mesh data at a time, then deforms it.
    //          Value is stored unaligned to memory.
    //          
    // TODO:    Add aligned version?
    static if (!SSESizedVectorsAreEmulated) {
        __m128 wwww = _mm_set_ps(weight, weight, weight, weight);

        // SIMD version
        size_t i = 0;
        for (; i < nu_aligndown(buffer.length, 4); i += 4) {

            // Load weights and vector
            __m128 xyzw = _mm_loadu_ps(cast(const(float)*)&buffer[i]);

            // Perform matrix multiplication and
            // Store 2 multiplied elements at once to mesh.
            __m128 weighted = _mm_mul_ps(xyzw, wwww);
            _mm_storeu_ps(cast(float*)&buffer[i], weighted);
        }

        // Tail iteration to finalize the multiplication
        while (i < buffer.length) {
            buffer[i] = buffer[i] * weight;
            i++;
        }
    } else {

        // Non-SIMD version
        foreach (i; 0 .. buffer.length) {
            buffer[i] = buffer[i] * weight;
        }
    }
}

@("simd_scale")
unittest {
    vec2[] array1 = new vec2[10_001];
    array1[] = vec2(0.5);

    simd_scale(cast(float[])array1, 0.5);
    foreach (i, value; array1) {
        assert(value == vec2(0.25, 0.25));
    }
}


/**
    Adds the weighted source to the destination buffer.

    Params:
        dst =       The destination buffer.
        src =       The buffer of values to add.
        weight =    The weight to scale the source by.
*/
void simd_fma_weight(ref float[] dst, float[] src, float weight) @nogc nothrow {
    if (weight == 0 || !weight.isFinite)
        return;

    size_t w_length = nu_min(dst.length, src.length);

    // NOTE:    SSE version of the algorithm.
    //          This algorithm loads 128 bits of mesh data at a time, then deforms it.
    //          Value is stored unaligned to memory.
    //          
    // TODO:    Add aligned version?
    static if (!SSESizedVectorsAreEmulated) {
        __m128 wwww = _mm_set_ps(weight, weight, weight, weight);

        // SIMD version
        size_t i = 0;
        for (; i < nu_aligndown(w_length, 4); i += 4) {

            // Load weights and vector
            __m128 dstxyzw = _mm_loadu_ps(cast(const(float)*)&dst[i]);
            __m128 srcxyzw = _mm_loadu_ps(cast(const(float)*)&src[i]);

            // Perform multiplication and
            // Store 2 multiplied elements at once to mesh.
            srcxyzw = _mm_mul_ps(srcxyzw, wwww);
            dstxyzw = _mm_add_ps(dstxyzw, srcxyzw);
            _mm_storeu_ps(cast(float*)&dst[i], dstxyzw);
        }

        // Tail iteration to finalize the multiplication
        while (i < w_length) {
            dst[i] += src[i] * weight;
            i++;
        }
    } else {

        // Non-SIMD version
        foreach (i; 0 .. w_length) {
            dst[i] += src[i] * weight;
        }
    }
}

@("simd_fma_weight")
unittest {
    float[] dst = new float[10_001];
    dst[] = 0.0f;

    float[] src = new float[10_001];
    src[] = 1.0f;

    // Should be zero.
    foreach (i, value; dst) {
        assert(value == 0.0f);
    }

    // Add 1.0 weighted by 1.0
    simd_fma_weight(dst, src, 1.0);
    foreach (i, value; dst) {
        assert(value == 1.0f);
    }

    // Add 1.0 weighted by 0.5
    simd_fma_weight(dst, src, 0.5);
    foreach (i, value; dst) {
        assert(value == 1.5f);
    }
}

void simd_div1(ref float[] dst, float divisor) @nogc nothrow {
    if (divisor == 0 || !divisor.isFinite)
        return;

    // NOTE:    SSE version of the algorithm.
    //          This algorithm loads 128 bits of mesh data at a time, then deforms it.
    //          Value is stored unaligned to memory.
    //          
    // TODO:    Add aligned version?
    static if (!SSESizedVectorsAreEmulated) {
        __m128 wwww = _mm_set_ps(divisor, divisor, divisor, divisor);

        // SIMD version
        size_t i = 0;
        for (; i < nu_aligndown(dst.length, 4); i += 4) {

            // Load vector, then divide by weights.
            __m128 dstxyzw = _mm_loadu_ps(cast(const(float)*)&dst[i]);
            _mm_storeu_ps(cast(float*)&dst[i], _mm_div_ps(dstxyzw, wwww));
        }

        // Tail iteration to finalize the multiplication
        while (i < dst.length) {
            dst[i] /= divisor;
            i++;
        }
    } else {

        // Non-SIMD version
        foreach (i; 0 .. dst.length) {
            dst[i] /= divisor;
        }
    }
}

@("simd_div1")
unittest {
    float[] dst = new float[10_001];
    dst[] = 10.0f;

    // Add 1.0 weighted by 1.0
    simd_div1(dst, 10.0);
    foreach (i, value; dst) {
        assert(value == 1.0f);
    }
}