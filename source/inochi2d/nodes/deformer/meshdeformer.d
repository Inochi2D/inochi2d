/**
    Inochi2D Mesh Deformer Node

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
        seagetch
*/
module inochi2d.nodes.deformer.meshdeformer;
import inochi2d.nodes.deformer;
import inochi2d.nodes;
import inochi2d.common;
import inochi2d.core;
import nulib.string;
import numem;

import inochi2d.core.math.simd;
import inteli;

alias MeshDeformerLUT = DeformerLUT!((DeformedMesh src, IDeformable target) @nogc {
    ptrdiff_t[2][] mappings = nu_malloca!(ptrdiff_t[2])(target.deformPoints.length);
    foreach (j; 0 .. mappings.length) {
        vec2 mp = target.deformPoints[j];

        mappings[j] = [-1, -1];
        foreach (k; 0 .. src.elementCount / 3) {
            uint[3] idx = [
                src.indices[(k * 3) + 0],
                src.indices[(k * 3) + 1],
                src.indices[(k * 3) + 2],
            ];
            Triangle tri = Triangle(
                src.points[idx[0]],
                src.points[idx[1]],
                src.points[idx[2]],
            );

            // Do some cheaper checks first.
            float minX = min(min(tri.p1.x, tri.p2.x), tri.p3.x);
            float maxX = max(max(tri.p1.x, tri.p2.x), tri.p3.x);
            float minY = min(min(tri.p1.y, tri.p2.y), tri.p3.y);
            float maxY = max(max(tri.p1.y, tri.p2.y), tri.p3.y);
            if (!(minX < mp.x && maxX > mp.x) &&
                !(minY < mp.y && maxY > mp.y))
                continue;

            // Mapping found, add it!
            mappings[j] = [k * 3, j];
            break;
        }
    }

    return mappings;
});

/**
    A deformer which deforms child nodes stored within it,
*/
@TypeId("MeshDeformer", IN_MAKE_TAG!(1, 2))  // Modern name
@TypeId("MeshGroup", IN_MAKE_TAG!(1, 2))  // Legacy name
class MeshDeformer : Deformer {
private:
    Mesh mesh_;
    DeformedMesh base_;
    DeformedMesh deformed_;
    vec2[] deformDeltas_;

    // Accelleration structures
    MeshDeformerLUT[] luts_;
    vec2[] deformBuffer_;

protected:

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
    */
    override
    void onSerialize(ref DataNode object) {
        super.onSerialize(object);

        // NOTE:    MeshData is set up to free its contents on
        //          scope exit.
        MeshData data = MeshData(mesh);
        object["mesh"] = data.serialize();
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object =    The DataNode to deserialize from.
            state =     The state of the deserializer.
    */
    override
    void onDeserialize(ref DataNode object, ref ModelState state) {
        super.onDeserialize(object, state);

        this.deformed_ = nogc_new!DeformedMesh();
        this.base_ = nogc_new!DeformedMesh();
        auto meshData = object.tryGet!MeshData(state, "mesh");
        this.mesh = Mesh.fromMeshData(meshData);

        if (state.doUpgrade08 && !object.tryGet(state, "dynamic_deformation", false)) {
            state.warning(nstring(this.name[], " uses static deformation, this was removed in 0.9..."));
        }

        if (state.doUpgrade08 && object.tryGet(state, "translate_children", false)) {
            state.warning(nstring(this.name[], " translates its children via deformation, this was removed in 0.9..."));
        }
    }

    /**
        Called during the early update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onPreUpdate(DrawList drawList) {
        super.onPreUpdate(drawList);
        this.resetDeform();
    }

    /**
        Called during the update phase of a new frame.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
    */
    override
    void onUpdate(float delta, DrawList drawList) {
        base_.pushMatrix(this.deformMatrix);
        deformed_.pushMatrix(this.deformMatrix);
        super.onUpdate(delta, drawList);
    }

    /**
        Called during the late update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onPostUpdate(DrawList drawList) {

        // No deltas?
        if (deformDeltas_.length == 0) {
            super.onPostUpdate(drawList);
            return;
        }

        // Calculate the deltas from the world matrix.
        simd_meshcopy(deformDeltas_, base_.points);
        simd_sub(deformDeltas_, deformed_.points);
        foreach (i, mesh; toDeform) {
            size_t w_length = nu_min(deformBuffer_.length, mesh.deformPoints.length);
            deformBuffer_[0 .. w_length] = vec2(0, 0);

            // Setup temporary buffer.
            foreach (entry; luts_[i].entries) {

                // Skip vertices out of bounds.
                if (entry[0] < 0 || entry[1] < 0 || entry[1] >= w_length)
                    continue;

                size_t p0 = mesh_.indices[entry[0] + 0];
                size_t p1 = mesh_.indices[entry[0] + 1];
                size_t p2 = mesh_.indices[entry[0] + 2];

                // Build triangle from start index.
                Triangle tri = Triangle(
                        deformed_.points[p0],
                        deformed_.points[p1],
                        deformed_.points[p2],
                );

                vec3 bc = tri.barycentric(mesh.deformPoints[entry[1]]);
                deformBuffer_[entry[1]] = -(
                        (deformDeltas_[p0] * bc.x) +
                        (deformDeltas_[p1] * bc.y) +
                        (deformDeltas_[p2] * bc.z)
                );
            }

            mesh.deform(deformBuffer_[0 .. w_length]);
        }

        super.onPostUpdate(drawList);
    }

    /**
        Called when the deformer's internal data should be
        rebuilt.
    */
    override
    void onRebuild() {
        super.onRebuild();

        // Delete old LUTs
        if (luts_)
            nu_freea(luts_);

        // Find children and rebuild.
        this.luts_ = nu_malloca!MeshDeformerLUT(toDeform.length);
        foreach (i, target; toDeform) {
            luts_[i].rebuild(deformed_, target);

            // Resize temporary deformation buffer.
            if (target.deformPoints.length > deformBuffer_.length)
                deformBuffer_ = deformBuffer_.nu_resize(target.deformPoints.length);
        }
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
        this.base_.pushMatrix(this.deformBaseMatrix);
    }

    /**
        The control points of the deformer.
    */
    override @property vec2[] controlPoints() @nogc => deformed_.points;
    override @property void controlPoints(vec2[] value) @nogc {
        import nulib.math : min;

        size_t m = min(value.length, deformed_.points.length);
        deformed_.points[0 .. m] = value[0 .. m];
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
}

mixin Register!(MeshDeformer, in_node_registry);
