/**
    Inochi2D Meshes

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.mesh;
import inochi2d.core.render.state;
import inochi2d.core.format; // TODO: Replace
import numem;
import inmath;

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
        Creates a mesh from a encoded Inochi2D MeshData
        structure.
    */
    this(MeshData meshData) {
        this._vtx = nu_malloca!VtxData(meshData.vertices.length);
        this._idx = nu_malloca!uint(meshData.indices.length);
        this._vto = meshData.vertices.nu_dup();

        foreach(i; 0.._vtx.length) {
            _vtx[i] = VtxData(meshData.vertices[i], meshData.uvs[i]);
        }
    }

    /**
        Creates a mesh from a encoded Inochi2D MeshData
        structure.
    */
    static Mesh fromMeshData(MeshData data) {
        return nogc_new!Mesh(data);
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