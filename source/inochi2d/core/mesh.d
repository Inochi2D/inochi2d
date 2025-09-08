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
import inochi2d.core.math.trig;
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
    VtxData[]   vtx_;
    uint[]      idx_;
    vec2[]      vto_;

public:

    /**
        The points of the vertices of the mesh.
    */
    @property vec2[] points() => vto_[0..$];

    /**
        The vertex data stored in the mesh.
    */
    @property VtxData[] vertices() => vtx_[0..$];

    /**
        The index data stored in the mesh.
    */
    @property uint[] indices() => idx_[0..$];

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
    @property uint triangleCount() => cast(uint)(idx_.length/3);

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
    this() { }

    /**
        Creates a mesh from a encoded Inochi2D MeshData
        structure.
    */
    this(MeshData meshData) {
        this.vtx_ = nu_malloca!VtxData(meshData.vertices.length);
        this.idx_ = meshData.indices.nu_dup();
        this.vto_ = meshData.vertices.nu_dup();

        foreach(i; 0..vtx_.length) {
            this.vtx_[i] = VtxData(meshData.vertices[i], meshData.uvs[i]);
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
        if (offset > idx_.length/3)
            return Triangle.init;
        
        return Triangle(
            vto_[idx_[(offset*3)+0]], 
            vto_[idx_[(offset*3)+1]], 
            vto_[idx_[(offset*3)+2]]
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
        foreach(i; 0..tris.length) {
            tris[i] = Triangle(
                vto_[idx_[(i*3)+0]], 
                vto_[idx_[(i*3)+1]], 
                vto_[idx_[(i*3)+2]]
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

    /**
        How many vertices are in the mesh.
    */
    @property uint vertexCount() => cast(uint)deformed_.length;

    /**
        How many indices are in the mesh.
    */
    @property uint elementCount() => cast(uint)parent_.idx_.length;

    /**
        How many triangles are in the mesh.
    */
    @property uint triangleCount() => cast(uint)(parent_.idx_.length/3);

    /**
        Bounds of the deformed mesh.
    */
    @property rect bounds() => delta_.getBounds();

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
        Constructs a new empty DeformedMesh
    */
    this() { }

    /**
        Deform the mesh by the given amount.

        Params:
            by =        The deltas to deform the mesh by
    */
    void deform(vec2[] by) {
        foreach(i; 0..delta_.length) {
            delta_[i] += by[i];
            deformed_[i].vtx = delta_[i];
        }
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
        deformed_[offset].vtx = delta_[offset];
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
        Gets an array of every triangle in the mesh.

        Returns:
            A nogc array of triangles that you must free
            yourself with $(D nu_freea).
    */
    Triangle[] getTriangles() {
        Triangle[] tris = nu_malloca!Triangle(triangleCount);
        foreach(i; 0..tris.length) {
            tris[i] = Triangle(
                delta_[parent_.idx_[(i*3)+0]], 
                delta_[parent_.idx_[(i*3)+1]], 
                delta_[parent_.idx_[(i*3)+2]]
            );
        }
        return tris;
    }

    /**
        Resets the deformation.
    */
    void reset() {
        this.deformed_[0..$] = parent_.vtx_[0..$];
        this.delta_[0..$] = parent_.vto_[0..$];
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

        vec2 origin = object.tryGet!vec2("origin");
        if (origin.isFinite) {
            foreach(i; 0..vertices.length) {
                vertices[i] -= origin;
            }
        }

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

/**
    Calculates bounding box of a mesh.

    Params:
        mesh = The mesh to get the bounds for.

    Returns:
        A rectangle enclosing the mesh.
*/
rect getBounds(vec2[] mesh) @nogc nothrow pure {
    vec2 minp = vec2(float.max, float.max);
    vec2 maxp = vec2(-float.max, -float.max);

    foreach(i; 0..mesh.length) {
        minp = vec2(min(minp.x, mesh[i].x), min(minp.y, mesh[i].y));
        maxp = vec2(max(maxp.x, mesh[i].x), max(maxp.y, mesh[i].y));
    }
    return rect(minp.x, minp.y, maxp.x-minp.x, maxp.y-minp.y);
}