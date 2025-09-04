/**
    Inochi2D Meshes

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.mesh;
import inochi2d.core.render.state;
import inochi2d.core.format; // TODO: Replace
import inochi2d.core.math.simd;
import numem;
import inmath;

/**
    Vertex Data that gets submitted to the GPU.
*/
struct VtxData {
    vec2 vtx;
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
    VtxData[]   _vtx;
    uint[]      _idx;
    vec2[]      _vto;

public:

    /**
        The points of the vertices of the mesh.
    */
    @property vec2[] points() => _vto[0..$];

    /**
        The vertex data stored in the mesh.
    */
    @property VtxData[] vertices() => _vtx[0..$];

    /**
        The index data stored in the mesh.
    */
    @property uint[] indices() => _idx[0..$];

    // Destructor
    ~this() {
        nu_freea(_vtx);
        nu_freea(_idx);
        nu_freea(_vto);
    }

    /**
        Creates an empty mesh.
    */
    this() { }

    /**
        Creates a mesh from a encoded Inochi2D MeshData
        structure.
    */
    this(MeshData meshData) {
        this._vtx = nu_malloca!VtxData(meshData.vertices.length);
        this._idx = meshData.indices.nu_dup();
        this._vto = meshData.vertices.nu_dup();

        foreach(i; 0.._vtx.length) {
            this._vtx[i] = VtxData(meshData.vertices[i], meshData.uvs[i]);
        }
    }

    /**
        Creates a mesh from a encoded Inochi2D MeshData
        structure.
    */
    static Mesh fromMeshData(MeshData data) {
        return nogc_new!Mesh(data);
    }

    /**
        Makes a clone of this mesh.

        Returns:
            A new mesh with the data cloned.
    */
    Mesh clone() {
        Mesh result = nogc_new!Mesh();
        result._vtx = this._vtx.nu_dup();
        result._idx = this._idx.nu_dup();
        result._vto = this._vto.nu_dup();
        return result;
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
    VtxData[] deformed_;
    vec2[] delta_;

public:

    /**
        The parent of the deformed mesh.
    */
    @property Mesh parent() => parent_;
    @property void parent(Mesh value) {
        this.parent_ = value;
        this.deformed_ = deformed_.nu_resize(value.points.length);
        this.delta_ = delta_.nu_resize(value.points.length);
    }

    /**
        The deformed points of the mesh.
    */
    @property vec2[] points() => delta_;

    /**
        The deformed vertices of the mesh.
    */
    @property VtxData[] vertices() => deformed_;

    /**
        The indices for the mesh.
    */
    @property uint[] indices() => parent.indices;

    // Destructor
    ~this() {
        nu_freea(deformed_);
        nu_freea(delta_);
    }

    /**
        Constructs a new DeformedMesh
    */
    this(Mesh parent) {
        this.parent_ = parent;

        this.deformed_ = nu_malloca!VtxData(parent.points.length);
        this.delta_ = nu_malloca!vec2(parent.points.length);
    }

    /**
        Deform the mesh by the given amount.
    */
    void deform(vec2[] by) {
        foreach(i; 0..deformed_.length) {
            delta_[i] += by[i];
            deformed_[i].vtx = delta_[i];
        }
    }

    /**
        Pushes a matrix to the deformed mesh.
    */
    void pushMatrix(mat4 matrix) {

        // NOTE: SIMD is slower in this instance due to how multiple arrays
        // are involved.
        foreach(i; 0..delta_.length) {
            delta_[i] = (matrix * vec4(delta_[i], 0, 1)).xy;
            deformed_[i].vtx = delta_[i];
        }
    }

    /**
        Resets the deformation.
    */
    void reset() {
        this.deformed_[0..$] = parent_.vertices[0..$];
        this.delta_[0..$] = parent_.points[0..$];
    }
}

/**
    Mesh data as stored in Inochi2D's file format.
*/
struct MeshData {

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

    /// Serialization handler
    void onSerialize(ref JSONValue object) {
        object["verts"] = vertices.serialize();
        object["uvs"] = uvs.serialize();
        object["indices"] = indices.serialize();
    }

    /// Deserialization handler
    void onDeserialize(ref JSONValue object) {
        if (object.isNull) 
            return;

        object.tryGetRef(vertices, "verts");
        object.tryGetRef(uvs, "uvs");
        object.tryGetRef(indices, "indices");
    }
}

/**
    Converts a Mesh back into a MeshData.

    Params:
        mesh = The mesh to convert.
    
    Returns:
        A GC allocated MeshData instance.
*/
MeshData toMeshData(Mesh mesh) {
    MeshData data;
    
    // Indices match 1:1; so just copy them into the GC.
    data.indices = mesh.indices.dup;
    data.vertices.length = mesh.vertices.length;
    data.uvs.length = mesh.vertices.length;
    foreach(i; 0..mesh.vertices.length) {
        data.vertices[i] = mesh.vertices[i].vtx;
        data.uvs[i] = mesh.vertices[i].uv;
    }
    return data;
}