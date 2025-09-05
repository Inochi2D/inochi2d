/*
    Inochi2D Lattice Deformer Node

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.deformer.latticedeformer;
import inochi2d.core.nodes.deformer;
import inochi2d.core;
import inmath.linalg;

/**
    A deformer which uses a 2D lattice as the basis for
    its deformation.
*/
@TypeId("LatticeDeformer")
class LatticeDeformer : Deformer {
private:
    int subdivs;
    vec2[] lattice;

protected:

    override
    void onSerialize(ref JSONValue object, bool recursive=true) {
        super.onSerialize(object, recursive);
        object["subdivisions"] = subdivs.serialize();
    }

    override
    void onDeserialize(ref JSONValue object) {
        super.onDeserialize(object);
        object.tryGetRef(subdivs, "subdivisions");

        lattice.length = subdivs*subdivs;
        lattice[0..$] = vec2.zero;
    }

public:

    /**
        Constructs a new MeshGroup node
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        The base position of the deformable's points.
    */
    override @property const(vec2)[] basePoints() => lattice;

    /**
        The control points of the deformer.
    */
    override @property vec2[] controlPoints() => lattice;
    override @property void controlPoints(vec2[] value) {
        import nulib.math : min;

        size_t m = min(value.length, lattice.length);
        lattice[0..m] = value[0..m];
    }

    /**
        The points which may be deformed by the deformer.
    */
    override void deform(vec2[] deformed, bool absolute) {
        super.deform(deformed, absolute);
    }

    override void resetDeform() {
        
    }

    override string typeId() { return "LatticeDeformer"; }
}