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
    BlendWeight[][] weights_;
    vec2[] deformDeltas_;

    void clearWeights() {
        foreach(i; 0..weights_.length) {
            nu_freea(weights_[i]);
        }
        nu_freea(weights_);
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
        
        this.deformed_ = nogc_new!DeformedMesh();
        this.base_ = nogc_new!DeformedMesh();
        this.mesh = Mesh.fromMeshData(object.tryGet!MeshData("mesh"));
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
        this.deformDeltas_ = deformDeltas_.nu_resize(mesh_.vertexCount);

        this.base_.parent = value;
        this.deformed_.parent = value;

        this.base_.reset();
        this.base_.pushMatrix(transform!false.matrix);
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
        The base position of the deformable's points, in world space.
    */
    override @property const(vec2)[] basePoints() => base_.points;

    /**
        The points which may be deformed by a deformer, in world space.
    */
    override @property vec2[] deformPoints() => deformed_.points;

    // Destructor
    ~this() {
        nu_freea(deformDeltas_);
        nogc_delete(deformed_);
        this.clearWeights();
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

    /**
        Updates the internal transformation matrix to apply to children.
    */
    override
    void update(float delta, DrawList drawList) {
        super.update(delta, drawList);
        
        // No deltas?
        if (deformDeltas_.length == 0)
            return;

        base_.pushMatrix(worldTransform.matrix);
        deformed_.pushMatrix(worldTransform.matrix);

        // Calculate the deltas from the world matrix.
        foreach(i; 0..deformDeltas_.length)
            deformDeltas_[i] = base_.points[i] - deformed_.points[i];

        // Use the weights to deform each subpoint by a delta determined
        // by the weight to each vertex in their triangle.
        foreach(i, mesh; toDeform) {
            if (weights_[i].length == 0)
                continue;

            foreach(j; 0..mesh.deformPoints.length) {
                BlendWeight weight = weights_[i][j];
                vec2 dfDelta = -(
                    (deformDeltas_[weight.indices[0]]*weight.weights.x) +
                    (deformDeltas_[weight.indices[1]]*weight.weights.y) +
                    (deformDeltas_[weight.indices[2]]*weight.weights.z)
                );
                mesh.deform(j, dfDelta);
            }
        }
    }

    override
    void rescan() {
        super.rescan();

        base_.reset();
        base_.pushMatrix(transform!true.matrix);

        // Clear weights lists.
        if (weights_.length < toDeform.length) {
            weights_ = weights_.nu_resize(toDeform.length);
            nogc_zeroinit(weights_[0..$]);
        }

        // Use barycentric coordinates of triangles to calculate
        // weights for deformed points.
        Triangle[] tris = base_.getTriangles();
        foreach(i, df; toDeform) {

            // Reset all the data in the weights.
            weights_[i] = weights_[i].nu_resize(df.deformPoints.length);
            weights_[i][0..$] = BlendWeight.init;

            mat4 baseTransformMat = df.baseTransform.matrix;
            foreach(j; 0..df.deformPoints.length) {

                // NOTE:    IDeformable doesn't have the internal mesh reference
                //          so instead we just multiply the point with their world
                //          matrix. 
                vec2 wpt = (baseTransformMat * vec4(df.basePoints[j], 0, 1)).xy;
                foreach(k, ref tri; tris) {
                    vec3 bc = tri.barycentric(wpt);
                    if (bc.x > 0 && bc.y > 0 && bc.z > 0) {
                        weights_[i][j] = BlendWeight(
                            [
                                mesh_.indices[(k*3)+0],
                                mesh_.indices[(k*3)+1],
                                mesh_.indices[(k*3)+2],
                            ], 
                            bc
                        );
                        break;
                    }
                }
            }
        }
        nu_freea(tris);
    }
}
mixin Register!(MeshDeformer, in_node_registry);

/**
    Weights for meshes
*/
struct BlendWeight {
    uint[3] indices = [0, 0, 0];
    vec3 weights = vec3(0, 0, 0);
}