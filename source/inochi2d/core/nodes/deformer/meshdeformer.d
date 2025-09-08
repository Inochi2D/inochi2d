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
    DeformedMesh base_;
    DeformedMesh deformed_;
    vec2[] deformDeltas_;

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
        
        this.deformed_ = nogc_new!DeformedMesh();
        this.base_ = nogc_new!DeformedMesh();
        this.mesh = Mesh.fromMeshData(object.tryGet!MeshData("mesh"));
    }

public:

    /**
        The mesh
    */
    @property Mesh mesh() @nogc => mesh_;
    final @property void mesh(Mesh value) @nogc {
        if (value is mesh_)
            return;
        
        if (mesh_)
            mesh_.release();

        this.mesh_ = value.retained();
        this.deformDeltas_ = deformDeltas_.nu_resize(mesh_.vertexCount);

        this.base_.parent = value;
        this.deformed_.parent = value;

        this.base_.reset();
        this.base_.pushMatrix(transform!false.matrix);
    }

    /**
        The control points of the deformer.
    */
    override @property vec2[] controlPoints() @nogc => deformed_.points;
    override @property void controlPoints(vec2[] value) @nogc {
        import nulib.math : min;

        size_t m = min(value.length, deformed_.points.length);
        deformed_.points[0..m] = value[0..m];
    }

    /**
        The base position of the deformable's points, in world space.
    */
    override @property const(vec2)[] basePoints() @nogc => base_.points;

    /**
        The points which may be deformed by a deformer, in world space.
    */
    override @property vec2[] deformPoints() @nogc => deformed_.points;

    // Destructor
    ~this() {
        nu_freea(deformDeltas_);
        nogc_delete(deformed_);
        nogc_delete(base_);
        mesh_.release();
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
        base_.reset();
    }

    override
    void preUpdate(DrawList drawList) {
        super.preUpdate(drawList);
        this.resetDeform();
    }

    override
    void update(float delta, DrawList drawList) {
        base_.pushMatrix(worldTransform.matrix);
        deformed_.pushMatrix(worldTransform.matrix);
        super.update(delta, drawList);
    }

    /**
        Updates the internal transformation matrix to apply to children.
    */
    override
    void postUpdate(DrawList drawList) {
        
        // No deltas?
        if (deformDeltas_.length == 0) {
            super.postUpdate(drawList);
            return;
        }

        // Calculate the deltas from the world matrix.
        foreach(i; 0..deformDeltas_.length)
            deformDeltas_[i] = base_.points[i] - deformed_.points[i];

        // Use the weights to deform each subpoint by a delta determined
        // by the weight to each vertex in their triangle.
        foreach(i, mesh; toDeform) {
            foreach(j; 0..mesh.deformPoints.length) {
                vec2 mp = mesh.deformPoints[j];

                foreach(k; 0..deformed_.elementCount/3) {
                    uint[3] idx = [
                        mesh_.indices[(k*3)+0],
                        mesh_.indices[(k*3)+1],
                        mesh_.indices[(k*3)+2],
                    ];
                    Triangle tri = Triangle(
                        base_.points[idx[0]],
                        base_.points[idx[1]],
                        base_.points[idx[2]],
                    );

                    // Do some cheaper checks first.
                    float minX = min(tri.p1.x, tri.p2.x, tri.p3.x);
                    float maxX = max(tri.p1.x, tri.p2.x, tri.p3.x);
                    float minY = min(tri.p1.y, tri.p2.y, tri.p3.y);
                    float maxY = max(tri.p1.y, tri.p2.y, tri.p3.y);
                    if (!(minX < mp.x && maxX > mp.x) && 
                        !(minY < mp.y && maxY > mp.y))
                        continue;

                    // Expensive check and barycentric coordinates.
                    vec3 bc = tri.barycentric(mp);
                    if (bc.x < 0 || bc.y < 0 || bc.z < 0)
                        continue;

                    mesh.deform(j, -(
                        (deformDeltas_[idx[0]]*bc.x) +
                        (deformDeltas_[idx[1]]*bc.y) +
                        (deformDeltas_[idx[2]]*bc.z)
                    ));
                    break;
                }
            }
        }

        super.postUpdate(drawList);
    }
}
mixin Register!(MeshDeformer, in_node_registry);