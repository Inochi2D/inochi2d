/*
    Inochi2D Welding

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.effect.weld;
import inochi2d.effect;
import inochi2d.core.math.deform;
import inochi2d.nodes.visual.part;
import inochi2d.nodes;
import inochi2d.core;
import inochi2d.common;
import inp.format;
import numath;
import numem;
import nulib;


/**
    An effect that welds other meshes to this mesh, forcing
    the welded meshes to be dragged towards paired vertices
*/
@TypeId("WeldEffect", 0x0001)
class WeldEffect : MeshEffect {
private:
@nogc:

    /**
        Target of the weld
    */
    IDeformable target_;
    GUID targetGUID;

    /**
        Vertices of the weld
    */
    WeldVertex[] vertices_;

protected:

    /**
        Serializes this MeshEffect to a DataNode.

        Params:
            object =    The DataNode to serialize to.
    */
    override
    void onSerialize(ref DataNode object) {
        super.onSerialize(object);

        object["target"] = (cast(Node)target_).guid.toString()[0..$];
        object["weights"] = DataNode.createArray();
        foreach(vertex; vertices_) {
            object["weights"] ~= DataNode(vertex.weight);
        }
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object =    The DataNode to deserialize from.
            state =     The state of the deserializer.
    */
    override
    void onDeserialize(ref DataNode object, ref ModelState state) {
        targetGUID = object.tryGetGUID(state, "target", "target");
        if ("weights" in object && object["weights"].isArray) {
            vertices_ = nu_malloca!WeldVertex(object["weights"].length);
            foreach(i, ref value; object["weights"].array) {
                vertices_[i].weight = value.tryCoerce!float(0.0);
            }
        }
    }

    /**
        Called when the Effect is to be finalized during loading.

        Params:
            state =     The state of the deserializer.
    */
    override
    void onFinalize(ref ModelState state) {
        if (targetGUID != GUID.nil) {
            this.target_ = cast(IDeformable)parent.puppet.find(targetGUID);
            this.rebuildWeights();
        }
    }

    /**
        Called after the full node update cycle.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onApply(DrawList drawList) {
        vec2[] targetMesh = target_.deformPoints;
        vec2[] sourceMesh = parent.deformPoints;
        foreach(i, ref WeldVertex weld; vertices_) {
            vec2 pdelta = targetMesh[weld.index] + weld.delta;
            vec2 p = lerp(sourceMesh[i], pdelta, weld.weight);
            parent.deform(i, p, true);
        }
    }

    void rebuildWelds() {
        if (vertices_)
            nu_freea(vertices_);

        if (target_) {
            vertices_ = nu_malloca!WeldVertex(parent.basePoints.length);
            this.rebuildWeights();
        }
    }

public:

    /**
        Target of the weld
    */
    final @property IDeformable target() => target_;
    final @property void target(IDeformable value) {
        this.target_ = value;
        this.rebuildWelds();
    }

    /**
        Constructs a new mesh effect.

        Params:
            parent = The parent of the mesh effect.
    */
    this(Part parent) {
        super(parent);
    }

    /**
        Rebuilds the weight deltas for the WeldEffect.
    */
    void rebuildWeights() {
        foreach(i, ref WeldVertex vtx; vertices_) {

            // Rebuild target vertex
            vec2 parentVtx = parent.basePoints[i];
            vtx.index = cast(uint)findClosest(parentVtx, target.basePoints);

            // Rebuild delta
            vec2 targetVtx = target.basePoints[vtx.index];
            vtx.delta = targetVtx - parentVtx;
        }
    }
}

/**
    A welded vertex
*/
struct WeldVertex {

    /**
        Weld delta
    */
    vec2 delta = vec2(0, 0);

    /**
        Index of the vertex to drag towards
    */
    uint index;

    /**
        Weight of the given line segment.
    */
    float weight = 0;
}