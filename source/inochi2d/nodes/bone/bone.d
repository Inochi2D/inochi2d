/**
    Inochi2D Bone Nodes

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.nodes.bone.bone;
import inochi2d.core.math.deform;
import inochi2d.core.math.simd;
import inochi2d.core.math;
import inochi2d.nodes;
import nulib.collections;
import numem;

/**
    A bone, bones are used to build skeletal hirearchies that deform
    other nodes via the use of bone weights.
*/
@TypeIdAbstract
@TypeId("Bone", IN_MAKE_TAG!(0, 3))
class Bone : Node {
private:
@nogc:
    vector!BoneTarget targets_;
    vec2[] boneOffsets;

    /**
        Finds the given target's index within the bone mapping.

        Params:
            toFind = The deformable to find.
    */
    ptrdiff_t findTargetIdx(IDeformable toFind) {
        foreach (i, target; targets_) {
            if (target.target is toFind)
                return i;
        }
        return -1;
    }

protected:

    /**
        Called during the update phase of a new frame.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
    */
    override
    void onUpdate(float delta, DrawList drawList) {
        auto offset = this.localTransformOffset;
        foreach (ref BoneTarget target; targets_) {
            size_t w_length = target.target.deformPoints.length;
            vec2[] w_verts = target.target.deformPoints;

            // Resize our temporary deformation buffer if need be.
            if (boneOffsets.length < w_length)
                boneOffsets = boneOffsets.nu_resize(w_length);

            // Copy over the base bone locations from deformed points.
            // Then add our delta bone offset transformation to every vertex.
            // Finally we apply weights based on the weight paint.
            boneOffsets[0 .. w_length] = w_verts[0 .. w_length];
            simd_mul(boneOffsets, offset.matrix);
            simd_mul_weight(boneOffsets, target.weights);

            // We then add the delta from the bone to the real deformation.
            target.target.deform(boneOffsets);
        }
    }

public:

    /**
        An immutable slice of the targets of this bone.
    */
    @property immutable(BoneTarget)[] targets() => cast(immutable(BoneTarget)[])targets_;

    /// Destructor
    ~this() {
        targets_.clear();
        nu_freea(boneOffsets);
    }

    /**
        Sets the weights for the given target.

        Params:
            target = The target to set weights for.
            weights = The weights to set.    
    */
    void setWeights(IDeformable target, float[] weights) {
        ptrdiff_t idx = this.findTargetIdx(target);
        if (idx >= 0) {
            targets_[idx].weights = weights.nu_dup();
        }
    }

    /**
        Adds a target

        Params:
            target = The target to add.
    */
    void addTarget(IDeformable target) {
        if (this.findTargetIdx(target) == -1) {
            this.targets_ ~= BoneTarget(target);
        }
    }

    /**
        Removes a target from this

        Params:
            target = The target to remove.
    */
    void removeTarget(IDeformable target) {
        ptrdiff_t idx = this.findTargetIdx(target);
        if (idx >= 0) {
            this.targets_.removeAt(idx);
        }
    }
}

mixin Register!(Bone, in_node_registry);

/**
    A target of a bone.
*/
struct BoneTarget {
@nogc:

    /// Destructor.
     ~this() {
        nu_freea(weights);
    }

    /**
        The target of the bone.    
    */
    IDeformable target;

    /**
        Bone weights
    */
    float[] weights;
}
