/**
    Inochi2D Meshes

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.mesh;
import inochi2d.core.render.state;
import inochi2d.core.serde;
import inochi2d.core.math.simd;
import inochi2d.core.math.trig;
import inochi2d.common;
import inochi2d.resource.mesh;
import numath;
import numem;

/**
    A mesh which recieves deformation data from the outside.
*/
final
class DeformedMesh : NuObject {
private:
@nogc:

    //-----------------------------------------------------------------------//
    //                                Mesh Data
    //-----------------------------------------------------------------------//
    Mesh parent_;
    vec2[] vertices_;
    vec2[] uvs_;

    //-----------------------------------------------------------------------//
    //                                 Metadata
    //-----------------------------------------------------------------------//
    rect aabb_;

    /**
        Recalculates the mesh bounding box.
    */
    void recalculateAABB() {
        vec2 minp = vec2(float.max, float.max);
        vec2 maxp = vec2(-float.max, -float.max);

        foreach (i; 0 .. vertices_.length) {
            minp = vec2(min(minp.x, vertices_[i].x), min(minp.y, vertices_[i].y));
            maxp = vec2(max(maxp.x, vertices_[i].x), max(maxp.y, vertices_[i].y));
        }
        this.aabb_ = rect(minp.x, minp.y, maxp.x - minp.x, maxp.y - minp.y);
    }

public:

    /**
        The parent of the deformed mesh.
    */
    @property Mesh parent() => parent_;
    @property void parent(Mesh value) {
        this.parent_ = value;
        if (parent_) {
            this.vertices_ = vertices_.nu_resize(value.vertices.length);
            this.uvs_ = uvs_.nu_resize(value.uvs.length);
            this.reset();
        }
    }

    /**
        The deformed uvs of the mesh.
    */
    @property vec2[] uvs() => uvs_;

    /**
        The deformed vertices of the mesh.
    */
    @property vec2[] vertices() => vertices_;

    /**
        The indices for the mesh.
    */
    @property uint[] indices() => parent_.indices;

    /**
        How many vertices are in the mesh.
    */
    @property uint vertexCount() => cast(uint)vertices_.length;

    /**
        How many indices are in the mesh.
    */
    @property uint elementCount() => cast(uint)parent_.indices.length;

    /**
        How many triangles are in the mesh.
    */
    @property uint triangleCount() => cast(uint)(parent_.indices.length / 3);

    /**
        Bounds of the deformed mesh.
    */
    @property rect bounds() => aabb_;

    // Destructor
    ~this() {
        nu_freea(vertices_);
    }

    /**
        Constructs a new DeformedMesh
    */
    this(Mesh parent) {
        this.parent_ = parent;
        this.vertices_ = nu_malloca!vec2(parent.vertices.length);
        this.uvs_ = nu_malloca!vec2(parent.uvs.length);
    }

    /**
        Constructs a new empty DeformedMesh
    */
    this() { }

    /**
        Deform the mesh by the given amount.

        Params:
            by =        The deltas to deform the mesh by
    */
    void deform(vec2[] by) {
        simd_add(vertices_, by);
        this.recalculateAABB();
    }

    /**
        Deforms the mesh uniformly by the given value.

        Params:
            by =        The deltas to deform the mesh by
    */
    void deform(vec2 by) {
        simd_add(vertices_, by);
        this.recalculateAABB();
    }

    /**
        Deforms a single vertex within the mesh by the 
        given amount.

        Params:
            offset =    Offset into the mesh to deform.
            by =        The delta to deform the mesh by
    */
    void deform(size_t offset, vec2 by) {
        if (offset >= vertices_.length)
            return;

        vertices_[offset] += by;
        this.recalculateAABB();
    }

    /**
        Pushes a matrix to the deformed mesh.
    */
    void pushMatrix(mat4 matrix) {
        simd_mul(vertices_, matrix);
        this.recalculateAABB();
    }

    /**
        Gets an array of every triangle in the mesh.

        Returns:
            A nogc array of triangles that you must free
            yourself with $(D nu_freea).
    */
    tri2f[] getTriangles() {
        tri2f[] tris = nu_malloca!tri2f(triangleCount);
        foreach (i; 0 .. tris.length) {
            tris[i] = tri2f(
                vertices_[parent_.indices[(i * 3) + 0]],
                vertices_[parent_.indices[(i * 3) + 1]],
                vertices_[parent_.indices[(i * 3) + 2]]
            );
        }
        return tris;
    }

    /**
        Applies an offset to the deformed mesh' UV coordinates.

        Params:
            offset =    The offset to apply to the texel coordinates.
    */
    void applyUVOffset(vec2 offset) {
        foreach (ref uv; uvs_) {
            uv += offset;
        }
    }

    /**
        Resets the deformation.
    */
    void reset() {
        if (parent_) {
            this.vertices_[0 .. $] = parent_.vertices[0 .. $];
            this.uvs_[0 .. $] = parent_.uvs[0 .. $];
            this.recalculateAABB();
        }
    }
}