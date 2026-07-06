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
    Calculates the bounding box of a mesh, for larger meshes SIMD
    is used to optimize this operation.

    Params:
        mesh = The points of the mesh.
*/
rect simd_calcbounds(vec2[] mesh) @nogc nothrow {

    // SIMD implementation will compare 2 vertices at the same time.
    // Then do a final pass on the result.
    __m128i m_off = __m128i([0, 1, 2, 3]);
    __m128i m_offu = __m128i([0, 1, 0, 1]);
    __m128 m_min = __m128([float.max, float.max, float.max, float.max]);
    __m128 m_max = __m128([-float.min_normal, -float.min_normal, -float.min_normal, -float.min_normal]);
    for (size_t i = 0; i < mesh.length; i += 2) {

        // NOTE:    In the case of an unaligned read, we use m_offu which just reads
        //          the same vertex twice.
        __m128 m1 = _mm_i32gather_ps!(4)(mesh[i].ptr, i + 2 > mesh.length ? m_offu : m_off);
        m_min = _mm_min_ps(m_min, m1);
        m_max = _mm_max_ps(m_max, m1);
    }

    // Unpack and construct rectangle.
    vec2 v_min = min(vec2(m_min[0], m_min[1]), vec2(m_min[2], m_min[3]));
    vec2 v_max = min(vec2(m_max[0], m_max[1]), vec2(m_max[2], m_max[3]));
    return rect(
            v_min.x,
            v_min.y,
            v_max.x - v_min.x,
            v_max.y - v_min.y,
    );
}

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
