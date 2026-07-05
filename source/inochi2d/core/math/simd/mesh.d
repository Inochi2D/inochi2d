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
void simd_deform(ref vec2[] mesh, vec2[] deform) @nogc nothrow {
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

@("simd_deform")
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
    Broadcasts vertex data from the given delta mesh into
    the given VtxData mesh.

    SIMD is used in the case of larger meshes.

    Params:
        mesh =  The mesh to broadcast the deltas to.
        delta = The deltas to broadcast to the mesh.
*/
void simd_broadcast_mesh(ref VtxData[] mesh, vec2[] delta) @nogc nothrow {

    // Write length, in case there's a mismatch of sizes.
    size_t w_length = nu_min(mesh.length, delta.length);

    // NOTE:    SSE version of the algorithm.
    //          Value is stored unaligned to memory.
    //          
    // TODO:    Add aligned version?
    static if (!SSESizedVectorsAreEmulated) {

        size_t i = 0;
        for (; i < nu_aligndown(w_length, 2); i += 2) {

            // Load vectors into SIMD variables, then uses SIMD store
            // to write it to the XY components of the VtxDatas.
            __m128 xyzw = _mm_loadu_ps(cast(float*)delta[i].ptr);
            _mm_storel_pi(cast(__m64*)&mesh[i], xyzw);
            _mm_storeh_pi(cast(__m64*)&mesh[i + 1], xyzw);
        }

        // Tail iteration to finalize the broadcast
        if (i < w_length) {
            mesh[i].vtx.data[0 .. 2] = delta[i].data[0 .. 2];
        }
    } else {

        // Non-SIMD version
        foreach (i; 0 .. w_length) {
            mesh[i].vtx.data[0 .. 2] = delta[i].data[0 .. 2];
        }
    }
}

@("simd_broadcast_mesh")
unittest {
    VtxData[] array1 = new VtxData[10_001];
    vec2[] array2 = new vec2[10_001];

    array1[] = VtxData(vtx_t(0), vec2(0));
    array2[] = vec2(1.0, 1.0);

    simd_broadcast_mesh(array1, array2);
    foreach (value; array1) {
        assert(value.vtx.xy == vec2(1.0, 1.0));
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
