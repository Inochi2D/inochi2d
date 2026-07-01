/**
    Inochi2D Lattice Deformer Node

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.nodes.deformer.latticedeformer;
import inochi2d.nodes.deformer;
import inochi2d.nodes;
import inochi2d.common;
import inochi2d.core;
import numath;
import numem;

/**
    A deformer which uses a 2D lattice as the basis for
    its deformation.
*/
@TypeId("LatticeDeformer", IN_MAKE_TAG!(2, 2))
class LatticeDeformer : Deformer {
private:
@nogc:
    int subdivs;
    vec2 size_;

    float[][] weights_;
    vec2[] latticeInitial;
    vec2[] lattice;

    // Regenerates the lattice points.
    void regenLattice() {
        if (subdivs == 0)
            return;

        this.latticeInitial = latticeInitial.nu_resize(subdivs * subdivs);
        this.lattice = lattice.nu_resize(latticeInitial.length);
        latticeInitial[0 .. $] = vec2.zero;

        vec2 iter = vec2(size_.x / subdivs, size_.y / subdivs);
        foreach (i; 0 .. lattice.length) {
            float x = mod(cast(float)i, cast(float)subdivs);
            float y = cast(float)i / cast(float)subdivs;
            latticeInitial[i] = iter * vec2(x, y);
        }
    }

    // Clears lattice weights
    void clearWeights() {
        foreach (i; 0 .. weights_.length) {
            nu_freea(weights_[i]);
        }
        nu_freea(weights_);
    }

protected:

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
    */
    override
    void onSerialize(ref DataNode object) {
        super.onSerialize(object);
        object["subdivisions"] = subdivs.serialize();
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
        object.tryGetRef(state, subdivs, "subdivisions");
        object.tryGetRef(state, size_, "size");
    }

    /**
        Called when the node is to finalize its deserialization from disk.

        Params:
            state =     The state of the deserializer.
    */
    override
    void onFinalize(ref ModelState state) {
        this.regenLattice();
    }

    /**
        Called during the update phase of a new frame.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
    */
    override
    void onUpdate(float delta, DrawList drawList) {
        super.onUpdate(delta, drawList);
    }

public:

    /**
        The size of the lattice (in pixels)
    */
    @property vec2 size() => size_;
    @property void size(vec2 value) {
        this.size_ = value;
        this.regenLattice();
    }

    /**
        The amount of subdivisions in the lattice.
    */
    @property int subdivisions() => subdivs;
    @property void subdivisions(int value) {
        this.subdivs = value;
        this.regenLattice();
    }

    /**
        The base position of the deformable's points.
    */
    override @property const(vec2)[] basePoints() => latticeInitial;

    /**
        The control points of the deformer.
    */
    override @property vec2[] controlPoints() => lattice;
    override @property void controlPoints(vec2[] value) {
        import nulib.math : min;

        size_t m = min(value.length, lattice.length);
        lattice[0 .. m] = value[0 .. m];
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
    void deform(vec2[] deformed, bool absolute) {
        super.deform(deformed, absolute);
    }

    /**
        Resets the deformation.
    */
    override
    void resetDeform() {
        lattice[0 .. $] = latticeInitial[0 .. $];
    }
}

mixin Register!(LatticeDeformer, in_node_registry);
