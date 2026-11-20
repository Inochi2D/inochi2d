/**
    Inochi2D Mesh SIMD Helpers

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.math.simd.mesh;
import inochi2d.core.math.simd;
import inochi2d.core.mesh;
import numem.core.math;
import numem.core.hooks;
import numath;
import inteli;

/**
    Performs deformation on the delta mesh.

    Params:
        mesh =      The mesh to deform.
        deform =    The mesh with the deformation deltas.
*/
void simd_add(ref vec2[] mesh, vec2[] deform) @nogc nothrow {
    size_t w_length = nu_min(mesh.length, deform.length);
    static if (!AVXSizedVectorsAreEmulated) {

        // NOTE:    AVX version of the algorithm.
        //          This algorithm loads 256 bits of mesh data at a time, then deforms it.
        //          Value is stored unaligned to memory.
        //          
        // TODO:    Add aligned version?
        size_t i = 0;
        for (; i < nu_aligndown(w_length, 4); i += 4) {

            // Get 4 values at the same from both the mesh and deform.
            __m256 m_xyzwuvst = _mm256_loadu_ps(cast(float*)&mesh[i]);
            __m256 d_xyzwuvst = _mm256_loadu_ps(cast(float*)&deform[i]);

            // Add and store 2 vectors at the same time.
            __m256 xyzwuvst = _mm256_add_ps(m_xyzwuvst, d_xyzwuvst);
            _mm256_storeu_ps(cast(float*)&mesh[i], xyzwuvst);
        }

        // SSE for 2-3 remaining values.
        if (i < nu_aligndown(w_length, 2)) {

            // Get 4 values at the same from both the mesh and deform.
            __m128 m_xyzw = _mm_loadu_ps(cast(float*)&mesh[i]);
            __m128 d_xyzw = _mm_loadu_ps(cast(float*)&deform[i]);

            // Add and store 2 vectors at the same time.
            __m128 xyzw = _mm_add_ps(m_xyzw, d_xyzw);
            _mm_storeu_ps(cast(float*)&mesh[i], xyzw);

            i += 2;
        }

        // Tail iteration to finalize the broadcast
        if (i < w_length) {
            __m128 m_xy01 = _mm_loadl_pi(IN_SIMD_IDENTITY, cast(const(__m64)*)&mesh[i]);
            __m128 d_xy01 = _mm_loadl_pi(IN_SIMD_IDENTITY, cast(const(__m64)*)&deform[i]);
            __m128 xy01 = _mm_add_ps(m_xy01, d_xy01);
            _mm_storel_pi(cast(__m64*)mesh[i].ptr, xy01);
        }
    } else static if (!SSESizedVectorsAreEmulated) {

        // NOTE:    SSE version of the algorithm.
        //          This algorithm loads 128 bits of mesh data at a time, then deforms it.
        //          Value is stored unaligned to memory.
        //          
        // TODO:    Add aligned version?
        size_t i = 0;
        for (; i < nu_aligndown(w_length, 2); i += 2) {

            // Get 4 values at the same from both the mesh and deform.
            __m128 m_xyzw = _mm_loadu_ps(cast(float*)&mesh[i]);
            __m128 d_xyzw = _mm_loadu_ps(cast(float*)&deform[i]);

            // Add and store 2 vectors at the same time.
            __m128 xyzw = _mm_add_ps(m_xyzw, d_xyzw);
            _mm_storeu_ps(cast(float*)&mesh[i], xyzw);
        }

        // Tail iteration to finalize the broadcast
        if (i < w_length) {
            __m128 m_xy01 = _mm_loadl_pi(IN_SIMD_IDENTITY, cast(const(__m64)*)&mesh[i]);
            __m128 d_xy01 = _mm_loadl_pi(IN_SIMD_IDENTITY, cast(const(__m64)*)&deform[i]);
            __m128 xy01 = _mm_add_ps(m_xy01, d_xy01);
            _mm_storel_pi(cast(__m64*)&mesh[i], xy01);
        }
    } else {

        // Non-SIMD version
        foreach (i; 0 .. w_length) {
            mesh[i] += deform[i];
        }
    }
}

@("simd_add")
unittest {
    vec2[] array1 = new vec2[10_001];
    vec2[] array2 = new vec2[10_001];

    array1[] = vec2(1.0, 1.0);
    array2[] = vec2(1.0, 0.0);

    simd_deform(array1, array2);
    foreach (value; array1) {
        assert(value == vec2(2.0, 1.0));
    }
}

/**
    Copies the data from the source buffer into the destination.

    Params:
        dst = Destination
        src = Source
*/
void simd_meshcopy(T)(ref T[] dst, T[] src) @nogc nothrow {
    nu_memcpy(dst.ptr, src.ptr, nu_min(dst.length, src.length) * T.sizeof);
}

/**
    Adds the values in the $(D rhs) mesh 
    to the $(D lhs) mesh.

    Params:
        lhs =   The left-hand side mesh.
        rhs =   The right-hand side mesh.
*/
void simd_add(T)(ref T[] lhs, T[] rhs) @nogc nothrow
if (is(T == VectorImpl!U, U...) && T.dimensions == 2) {
    size_t w_length = nu_min(lhs.length, rhs.length);

    // NOTE:    SSE version of the algorithm.
    //          This algorithm loads 128 bits of mesh data at a time, then deforms it.
    //          Value is stored unaligned to memory.
    //          
    // TODO:    Add aligned version?
    static if (!SSESizedVectorsAreEmulated) {

        // SIMD version
        size_t i = 0;
        for (; i < nu_aligndown(w_length, 2); i += 2) {
            __m128 xyzw = _mm_load_ps(cast(const(float)*)&lhs[i]);
            __m128 abcd = _mm_load_ps(cast(const(float)*)&rhs[i]);
            _mm_storeu_ps(cast(float*)&lhs[i], _mm_add_ps(xyzw, abcd));
        }

        // Tail iteration to finalize the multiplication
        if (i < w_length) {
            lhs[i] = lhs[i] + rhs[i];
        }
    } else {

        // Non-SIMD version
        foreach (i; 0 .. w_length) {
            lhs[i] = lhs[i] + rhs[i];
        }
    }
}

/**
    Subtracts the values in the $(D rhs) mesh 
    from the $(D lhs) mesh.

    Params:
        lhs =   The left-hand side mesh.
        rhs =   The right-hand side mesh.
*/
void simd_sub(T)(ref T[] lhs, T[] rhs) @nogc nothrow
if (is(T == VectorImpl!U, U...) && T.dimensions == 2) {
    size_t w_length = nu_min(lhs.length, rhs.length);

    // NOTE:    SSE version of the algorithm.
    //          This algorithm loads 128 bits of mesh data at a time, then deforms it.
    //          Value is stored unaligned to memory.
    //          
    // TODO:    Add aligned version?
    static if (!SSESizedVectorsAreEmulated) {

        // SIMD version
        size_t i = 0;
        for (; i < nu_aligndown(w_length, 2); i += 2) {
            __m128 xyzw = _mm_load_ps(cast(const(float)*)&lhs[i]);
            __m128 abcd = _mm_load_ps(cast(const(float)*)&rhs[i]);
            _mm_storeu_ps(cast(float*)&lhs[i], _mm_sub_ps(xyzw, abcd));
        }

        // Tail iteration to finalize the multiplication
        if (i < w_length) {
            lhs[i] = lhs[i] - rhs[i];
        }
    } else {

        // Non-SIMD version
        foreach (i; 0 .. w_length) {
            lhs[i] = lhs[i] - rhs[i];
        }
    }
}

/**
    Multiplies the values in the $(D rhs) mesh 
    with the $(D lhs) mesh.

    Params:
        lhs =   The left-hand side mesh.
        rhs =   The right-hand side mesh.
*/
void simd_mul(T)(ref T[] lhs, T[] rhs) @nogc nothrow
if (is(T == VectorImpl!U, U...) && T.dimensions == 2) {
    size_t w_length = nu_min(lhs.length, rhs.length);

    // NOTE:    SSE version of the algorithm.
    //          This algorithm loads 128 bits of mesh data at a time, then deforms it.
    //          Value is stored unaligned to memory.
    //          
    // TODO:    Add aligned version?
    static if (!SSESizedVectorsAreEmulated) {

        // SIMD version
        size_t i = 0;
        for (; i < nu_aligndown(w_length, 2); i += 2) {
            __m128 xyzw = _mm_load_ps(cast(const(float)*)&lhs[i]);
            __m128 abcd = _mm_load_ps(cast(const(float)*)&rhs[i]);
            _mm_storeu_ps(cast(float*)&lhs[i], _mm_mul_ps(xyzw, abcd));
        }

        // Tail iteration to finalize the multiplication
        if (i < w_length) {
            lhs[i] = lhs[i] * rhs[i];
        }
    } else {

        // Non-SIMD version
        foreach (i; 0 .. w_length) {
            lhs[i] = lhs[i] * rhs[i];
        }
    }
}

/**
    Calculates an axis-aligned bounding box which encapsulates
    the given mesh.

    Params:
        dst =   The rectangle to store the AABB within.
        mesh =  The mesh to get the AABB for.
*/
void simd_aabb(T)(ref rect dst, T[] mesh) @nogc nothrow
if (is(T == VectorImpl!U, U...) && T.dimensions == 2) {
    size_t w_length = mesh.length;
    vec2 v_min = float.max;
    vec2 v_max = -float.max;

    // NOTE:    SSE version of the algorithm.
    //          This algorithm loads 128 bits of mesh data at a time, then deforms it.
    //          Value is stored unaligned to memory.

    static if (!SSESizedVectorsAreEmulated) {
        __m128 m_min = __m128([float.max, float.max, float.max, float.max]);
        __m128 m_max = __m128([-float.max, -float.max, -float.max, -float.max]);
    
        // SIMD version
        size_t i = 0;
        for (; i < nu_aligndown(w_length, 2); i += 2) {
            __m128 xyzw = _mm_loadu_ps(cast(const(float)*)&mesh[i]);
            m_min = _mm_min_ps(m_min, xyzw);
            m_max = _mm_max_ps(m_max, xyzw);
        }
        v_min = min(vec2(m_min[0], m_min[1]), vec2(m_min[2], m_min[3]));
        v_max = max(vec2(m_max[0], m_max[1]), vec2(m_max[2], m_max[3]));
    }

    // Tail iteration
    for (; i < w_length; i++) {
        v_min = min(v_min, mesh[i]);
        v_max = max(v_max, mesh[i]);
    }
    dst.x = v_min.x;
    dst.y = v_min.y;
    dst.width = v_max.x - v_min.x;
    dst.height = v_max.y - v_min.y;
}