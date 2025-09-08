/**
    Inochi2D Mesh Deformer Node

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen, seagetch
*/
module inochi2d.core.nodes.deformer.meshdeformer;
import inochi2d.core.nodes.deformer;
import inochi2d.core.nodes.drawable;
import inochi2d.core.math;
import inochi2d.core;
import std.exception;
import std.typecons: tuple, Tuple;
import std.stdio;
import numem;

/**
    A deformer which deforms child nodes stored within it,

*/
@TypeId("MeshGroup", 0x0102)
class MeshDeformer : Deformer {
private:
    Mesh mesh_;
    DeformedMesh deformed_;
    Triangle[] triangles_;
    ushort[] bitmask_;
    vec4 bounds;
    
    vec4 calculateVertexBounds(vec2[] vertices) {
        vec4 bounds = vec4(float.max, float.max, -float.max, -float.max);
        foreach (v; vertices) {
            bounds = vec4(min(bounds.x, v.x), min(bounds.y, v.y), max(bounds.z, v.x), max(bounds.w, v.y));
        }
        bounds.x = floor(bounds.x);
        bounds.y = floor(bounds.y);
        bounds.z = ceil(bounds.z);
        bounds.w = ceil(bounds.w);
        return bounds;
    }

    void rebuildStructures() {
        if (mesh_.indices.length == 0) {
            triangles_.length = 0;
            bitmask_.length   = 0;
            return;
        }

        // Calculate offset matrices for all children.
        bounds = calculateVertexBounds(mesh_.points);
        triangles_.length = 0;
        foreach (i; 0..mesh_.indices.length / 3) {
            Triangle t;
            vec2 p1 = mesh_.points[mesh_.indices[3*i]];
            vec2 p2 = mesh_.points[mesh_.indices[3*i+1]];
            vec2 p3 = mesh_.points[mesh_.indices[3*i+2]];

            vec2 axis0 = p2 - p1;
            float axis0len = axis0.length;
            axis0 /= axis0len;
            vec2 axis1 = p3 - p1;
            float axis1len = axis1.length;
            axis1 /= axis1len;

            vec3 raxis1 = mat3([axis0.x, axis0.y, 0, -axis0.y, axis0.x, 0, 0, 0, 1]) * vec3(axis1, 1);
            float cosA = raxis1.x;
            float sinA = raxis1.y;
            t.offsetMatrix = 
                mat3([axis0len > 0? 1/axis0len: 0, 0, 0,
                        0, axis1len > 0? 1/axis1len: 0, 0,
                        0, 0, 1]) * 
                mat3([1, -cosA/sinA, 0, 
                        0, 1/sinA, 0, 
                        0, 0, 1]) * 
                mat3([axis0.x, axis0.y, 0, 
                        -axis0.y, axis0.x, 0, 
                        0, 0, 1]) * 
                mat3([1, 0, -p1.x, 
                        0, 1, -p1.y, 
                        0, 0, 1]);
            triangles_ ~= t;
        }

        // Construct bitmask
        int width  = cast(int)(ceil(bounds.z) - floor(bounds.x) + 1);
        int height = cast(int)(ceil(bounds.w) - floor(bounds.y) + 1);
        bitmask_.length = width * height;
        bitmask_[] = 0;
        foreach (size_t i, t; triangles_) {
            vec2[3] tvertices = [
                mesh_.points[mesh_.indices[3*i]],
                mesh_.points[mesh_.indices[3*i+1]],
                mesh_.points[mesh_.indices[3*i+2]]
            ];

            vec4 tbounds = calculateVertexBounds(tvertices);
            int bwidth  = cast(int)(ceil(tbounds.z) - floor(tbounds.x) + 1);
            int bheight = cast(int)(ceil(tbounds.w) - floor(tbounds.y) + 1);
            int top  = cast(int)floor(tbounds.y);
            int left = cast(int)floor(tbounds.x);
            foreach (y; 0..bheight) {
                foreach (x; 0..bwidth) {
                    vec2 pt = vec2(left + x, top + y);
                    if (isPointInTriangle(pt, tvertices)) {
                        ushort id = cast(ushort)(i + 1);
                        pt-= bounds.xy;
                        bitmask_[cast(int)(pt.y * width + pt.x)] = id;
                    }
                }
            }
        }
    }

protected:
    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void onSerialize(ref JSONValue object, bool recursive=true) {
        super.onSerialize(object, recursive);

        MeshData data = mesh.toMeshData();
        object["mesh"] = data.serialize();
    }

    override
    void onDeserialize(ref JSONValue object) {
        super.onDeserialize(object);

        this.mesh_ = Mesh.fromMeshData(object.tryGet!MeshData("mesh"));
        this.deformed_ = nogc_new!DeformedMesh(mesh_);
    }

    override
    void finalize() {
        super.finalize();
        this.rescan();
    }

public:

    /**
        The mesh
    */
    @property Mesh mesh() => mesh_;
    final @property void mesh(Mesh value) @nogc {
        if (value is mesh_)
            return;
        
        if (mesh_)
            mesh_.release();

        this.mesh_ = value.retained();
        this.deformed_.parent = value;
    }

    /**
        The control points of the deformer.
    */
    override @property vec2[] controlPoints() => deformed_.points;
    override @property void controlPoints(vec2[] value) {
        import nulib.math : min;

        size_t m = min(value.length, deformed_.points.length);
        deformed_.points[0..m] = value[0..m];
    }

    /**
        The base position of the deformable's points.
    */
    override @property const(vec2)[] basePoints() => mesh_.points;

    /**
        The points which may be deformed by the deformer.
    */
    override @property vec2[] deformPoints() => deformed_.points;

    // Destructor
    ~this() {
        mesh_.release();
        nogc_delete(deformed_);
    }

    /**
        Constructs a new MeshGroup node
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        Deforms the IDeformable.

        Params:
            deformed =  The deformation delta.
            absolute =  Whether the deformation is absolute,
                        replacing the original deformation.
    */
    override
    void deform(vec2[] deformed, bool absolute = false) {
        deformed_.deform(deformed);
    }

    /**
        Resets the deformation for the IDeformable.
    */
    override
    void resetDeform() {
        deformed_.reset();
    }

    /**
        Updates the internal transformation matrix to apply to children.
    */
    override
    void update(float delta, DrawList drawList) {
        super.update(delta, drawList);

        if (deformPoints.length > 0) {
            this.triangles_.length = mesh_.points.length;
            foreach (i; 0..deformed_.points.length) {
                auto p1 = deformed_.points[deformed_.indices[i * 3]];
                auto p2 = deformed_.points[deformed_.indices[i * 3 + 1]];
                auto p3 = deformed_.points[deformed_.indices[i * 3 + 2]];
                triangles_[i].transformMatrix = mat3([p2.x - p1.x, p3.x - p1.x, p1.x,
                                                        p2.y - p1.y, p3.y - p1.y, p1.y,
                                                        0, 0, 1]) * triangles_[i].offsetMatrix;
            }
        }
    }

    override
    void postUpdate(DrawList drawList) {
        foreach(df; toDeform) {
            mat4 centerMatrix = df.worldMatrix.inverse;
            auto r = rect(bounds.x, bounds.y, (ceil(bounds.z) - floor(bounds.x) + 1), (ceil(bounds.w) - floor(bounds.y) + 1));
            foreach(i, vertex; df.deformPoints) {
                vec2 cVertex = vec2(centerMatrix * vec4(vertex+df.deformPoints[i], 0, 1));
                ptrdiff_t index = -1;
                if (bounds.x <= cVertex.x && cVertex.x < bounds.z && bounds.y <= cVertex.y && cVertex.y < bounds.w) {
                    ushort bit = bitmask_[cast(int)(cVertex.y - bounds.y) * cast(int)r.width + cast(int)(cVertex.x - bounds.x)];
                    index = bit - 1;
                }
                vec2 newPos = (index < 0) ? cVertex : (triangles_[index].transformMatrix * vec3(cVertex, 1)).xy;
                df.deformPoints[i] = newPos - df.basePoints[i];
            }
        }
        super.postUpdate(drawList);
    }

    override
    void rescan() {
        super.rescan();
        this.rebuildStructures();
    }
}
mixin Register!(MeshDeformer, in_node_registry);

private
struct Triangle {
    mat3 offsetMatrix;
    mat3 transformMatrix;
}