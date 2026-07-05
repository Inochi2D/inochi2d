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
import numath;
import numem;

version (IN_VEC3_POSITION)
    alias vtx_t = vec3;
else
    alias vtx_t = vec2;

/**
    Vertex Data that gets submitted to the GPU.
*/
struct VtxData {
    vtx_t vtx;
    vec2 uv;
}

/**
    A collection of points connected to create a mesh.

    This is a nogc reimplementation of Inochi2D's mesh
    handling, made to be more optimal to send to the GPU.
*/
class Mesh : NuRefCounted {
private:
@nogc:
    VtxData[] vtx_;
    uint[] idx_;
    vec2[] vto_;

public:

    /**
        The points of the vertices of the mesh.
    */
    @property vec2[] points() => vto_[0 .. $];

    /**
        The vertex data stored in the mesh.
    */
    @property VtxData[] vertices() => vtx_[0 .. $];

    /**
        The index data stored in the mesh.
    */
    @property uint[] indices() => idx_[0 .. $];

    /**
        How many vertices are in the mesh.
    */
    @property uint vertexCount() => cast(uint)vtx_.length;

    /**
        How many indices are in the mesh.
    */
    @property uint elementCount() => cast(uint)idx_.length;

    /**
        How many triangles are in the mesh.
    */
    @property uint triangleCount() => cast(uint)(idx_.length / 3);

    /**
        Bounds of the deformed mesh.
    */
    @property rect bounds() => vto_.getBounds();

    // Destructor
    ~this() {
        nu_freea(vtx_);
        nu_freea(idx_);
        nu_freea(vto_);
    }

    /**
        Creates an empty mesh.
    */
    this() {
    }

    /**
        Creates a mesh from a encoded Inochi2D MeshData
        structure.
    */
    this(ref MeshData meshData) {
        this.vtx_ = nu_malloca!VtxData(meshData.vertices.length);
        this.idx_ = meshData.indices.nu_dup();
        this.vto_ = meshData.vertices.nu_dup();

        foreach (i; 0 .. vtx_.length) {
            version (IN_VEC3_POSITION) {
                this.vtx_[i] = VtxData(vec3(this.vto_[i], 0), meshData.uvs[i]);
            } else {
                this.vtx_[i] = VtxData(this.vto_[i], meshData.uvs[i]);
            }
        }
    }

    /**
        Creates a mesh from a encoded Inochi2D MeshData
        structure.

        Params:
            data =  The mesh data.
            free =  Whether to free the original mesh data.
    */
    static Mesh fromMeshData(ref MeshData data, bool free = true) {
        auto result = nogc_new!Mesh(data);

        if (free)
            data.free();

        return result;
    }

    /**
        Makes a clone of this mesh.

        Returns:
            A new mesh with the data cloned.
    */
    Mesh clone() {
        Mesh result = nogc_new!Mesh();
        result.vtx_ = this.vtx_.nu_dup();
        result.idx_ = this.idx_.nu_dup();
        result.vto_ = this.vto_.nu_dup();
        return result;
    }

    /**
        Gets the triangle in the mesh at the given offset.

        Params:
            offset = The offset into the mesh.

        Returns:
            The requested triangle.
    */
    Triangle getTriangle(uint offset) {
        if (offset > idx_.length / 3)
            return Triangle.init;

        return Triangle(
                vto_[idx_[(offset * 3) + 0]].xy,
                vto_[idx_[(offset * 3) + 1]].xy,
                vto_[idx_[(offset * 3) + 2]].xy
        );
    }

    /**
        Gets an array of every triangle in the mesh.

        Returns:
            A nogc array of triangles that you must free
            yourself with $(D nu_freea).
    */
    Triangle[] getTriangles() {
        Triangle[] tris = nu_malloca!Triangle(triangleCount);
        foreach (i; 0 .. tris.length) {
            tris[i] = Triangle(
                    vto_[idx_[(i * 3) + 0]].xy,
                    vto_[idx_[(i * 3) + 1]].xy,
                    vto_[idx_[(i * 3) + 2]].xy
            );
        }
        return tris;
    }

    /**
        Frees this mesh.
    */
    void free() {
        auto self = this;
        nogc_delete(self);
    }
}

/**
    A mesh which recieves deformation data from the outside.
*/
final
class DeformedMesh : NuObject {
private:
@nogc:
    Mesh parent_;
    VtxData[] vertices_;
    vec2[] delta_;

public:

    /**
        The parent of the deformed mesh.
    */
    @property Mesh parent() => parent_;
    @property void parent(Mesh value) {
        this.parent_ = value;
        if (parent_) {
            this.vertices_ = vertices_.nu_resize(value.points.length);
            this.delta_ = delta_.nu_resize(value.points.length);
            this.reset();
        }
    }

    /**
        The deformed points of the mesh.
    */
    @property vec2[] points() => delta_;

    /**
        The deformed vertices of the mesh.
    */
    @property VtxData[] vertices() => vertices_;

    /**
        The indices for the mesh.
    */
    @property uint[] indices() => parent.indices;

    /**
        How many vertices are in the mesh.
    */
    @property uint vertexCount() => cast(uint)vertices_.length;

    /**
        How many indices are in the mesh.
    */
    @property uint elementCount() => cast(uint)parent_.idx_.length;

    /**
        How many triangles are in the mesh.
    */
    @property uint triangleCount() => cast(uint)(parent_.idx_.length / 3);

    /**
        Bounds of the deformed mesh.
    */
    @property rect bounds() => delta_.getBounds();

    // Destructor
    ~this() {
        nu_freea(vertices_);
        nu_freea(delta_);
    }

    /**
        Constructs a new DeformedMesh
    */
    this(Mesh parent) {
        this.parent_ = parent;

        this.vertices_ = nu_malloca!VtxData(parent.points.length);
        this.delta_ = nu_malloca!vec2(parent.points.length);
    }

    /**
        Constructs a new empty DeformedMesh
    */
    this() {
    }

    /**
        Deform the mesh by the given amount.

        Params:
            by =        The deltas to deform the mesh by
    */
    void deform(vec2[] by) {
        simd_deform(delta_, by);
        simd_broadcast_mesh(vertices_, delta_);
    }

    /**
        Deforms the mesh uniformly by the given value.

        Params:
            by =        The deltas to deform the mesh by
    */
    void deform(vec2 by) {
        simd_offset(delta_, by);
        simd_broadcast_mesh(vertices_, delta_);
    }

    /**
        Deforms a single vertex within the mesh by the 
        given amount.

        Params:
            offset =    Offset into the mesh to deform.
            by =        The delta to deform the mesh by
    */
    void deform(size_t offset, vec2 by) {
        if (offset >= delta_.length)
            return;

        delta_[offset] += by;
        vertices_[offset].vtx.x = delta_[offset].x;
        vertices_[offset].vtx.y = delta_[offset].y;
    }

    /**
        Pushes a matrix to the deformed mesh.
    */
    void pushMatrix(mat4 matrix) {
        simd_mul(delta_, matrix);
        simd_broadcast_mesh(vertices_, delta_);
    }

    /**
        Gets an array of every triangle in the mesh.

        Returns:
            A nogc array of triangles that you must free
            yourself with $(D nu_freea).
    */
    Triangle[] getTriangles() {
        Triangle[] tris = nu_malloca!Triangle(triangleCount);
        foreach (i; 0 .. tris.length) {
            tris[i] = Triangle(
                    delta_[parent_.idx_[(i * 3) + 0]].xy,
                    delta_[parent_.idx_[(i * 3) + 1]].xy,
                    delta_[parent_.idx_[(i * 3) + 2]].xy
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
        foreach (ref vtx; vertices_) {
            vtx.uv += offset;
        }
    }

    /**
        Resets the deformation.
    */
    void reset() {
        this.vertices_[0 .. $] = parent_.vtx_[0 .. $];
        this.delta_[0 .. $] = parent_.vto_[0 .. $];
    }
}

/**
    Mesh data as stored in Inochi2D's file format.
*/
struct MeshData {
@nogc:

    /**
        Vertices in the mesh
    */
    vec2[] vertices;

    /**
        Base uvs
    */
    vec2[] uvs;

    /**
        Indices in the mesh
    */
    uint[] indices;

    /**
        Constructs a new MeshData from slices of mesh data.

        Params:
            vertices =  The vertices of the mesh.
            uvs =       The UV coordinates of the mesh.
            indices =   The indices of the mesh.
    */
    this(vec2[] vertices, vec2[] uvs, uint[] indices) {
        this.vertices = vertices.nu_dup();
        this.uvs = uvs.nu_dup();
        this.indices = indices.nu_dup();
    }

    /**
        Constructs a new MeshData from a refcounted mesh.

        Params:
            mesh =  The mesh to extract a MeshData from.
    */
    this(Mesh mesh) {
        this.indices = mesh.indices.nu_dup;
        this.vertices = nu_malloca!vec2(mesh.vertices.length);
        this.uvs = nu_malloca!vec2(mesh.vertices.length);
        foreach (i; 0 .. mesh.vertices.length) {
            this.vertices[i] = mesh.vertices[i].vtx.xy;
            this.uvs[i] = mesh.vertices[i].uv;
        }
    }

    /// Serialization handler
    void onSerialize(ref DataNode object) {
        object["verts"] = (cast(float[])vertices).serialize();
        object["uvs"] = (cast(float[])uvs).serialize();
        object["indices"] = indices.serialize();
    }

    /// Deserialization handler
    void onDeserialize(ref DataNode object, ref ModelState state) {
        if (object.isNull)
            return;

        // Load vertices as tightly packed floats.
        float[] vtxbuf;
        object.tryGetRef(state, vtxbuf, "verts");
        this.vertices = cast(vec2[])vtxbuf[0 .. nu_aligndown(vtxbuf.length, 2)];

        // Load UVs as tightly packed floats.
        float[] uvbuf;
        object.tryGetRef(state, uvbuf, "uvs");
        this.uvs = cast(vec2[])uvbuf[0 .. nu_aligndown(uvbuf.length, 2)];

        object.tryGetRef(state, indices, "indices");
        vec2 origin = object.tryGet!vec2(state, "origin");
        if (origin.isFinite) {
            foreach (i; 0 .. vertices.length) {
                vertices[i] -= origin;
            }
        }
    }

    void free() {
        nu_freea(vertices);
        nu_freea(uvs);
        nu_freea(indices);
    }
}

/**
    Calculates bounding box of a mesh.

    Params:
        mesh = The mesh to get the bounds for.

    Returns:
        A rectangle enclosing the mesh.
*/
rect getBounds(T)(T[] mesh) @nogc nothrow pure
if (isVector!T) {
    vec2 minp = vec2(float.max, float.max);
    vec2 maxp = vec2(-float.max, -float.max);

    foreach (i; 0 .. mesh.length) {
        minp = vec2(min(minp.x, mesh[i].x), min(minp.y, mesh[i].y));
        maxp = vec2(max(maxp.x, mesh[i].x), max(maxp.y, mesh[i].y));
    }
    return rect(minp.x, minp.y, maxp.x - minp.x, maxp.y - minp.y);
}
