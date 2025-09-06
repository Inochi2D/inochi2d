/*
    Inochi2D Deformers

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.deformer;
import inochi2d.core.nodes;
import inochi2d.core.math;
import nulib;
import numem;

public import inochi2d.core.nodes.deformer.meshdeformer;
public import inochi2d.core.nodes.deformer.latticedeformer;

/**
    A node which deforms the vertex data of nodes beneath
    it.

    Deformations happen in world space
*/
@TypeId("Deformer", 0x0002)
@TypeIdAbstract
abstract
class Deformer : Node, IDeformable {
private:
    void scanPartsRecurse(Node node) {
        import std.stdio : writeln;

        // Don't need to scan null nodes
        if (node is null) return;

        // Do the main check
        if (IDeformable deformable = cast(IDeformable)node)
            toDeform ~= deformable;
    
        foreach(child; node.children) {
            scanPartsRecurse(child);
        }
    }

protected:

    /**
        A list of the nodes to deform.
    */
    IDeformable[] toDeform;

    /**
        Finalizes the deformer.
    */
    override
    void finalize() {
        super.finalize();
        this.rescan();
    }

public:

    ~this() { }

    /**
        Constructs a new MeshGroup node
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        The control points of the deformer.
    */
    abstract @property vec2[] controlPoints();
    abstract @property void controlPoints(vec2[] value);

    /**
        The base position of the deformable's points.
    */
    abstract @property const(vec2)[] basePoints();

    /**
        Local matrix of the deformable object.
    */
    override @property mat4 localMatrix() => transform.matrix;

    /**
        World matrix of the deformable object.
    */
    override @property mat4 worldMatrix() => globalTransform.matrix;

    /**
        The points which may be deformed by the deformer.
    */
    override @property vec2[] deformPoints() => controlPoints();
    override void deform(vec2[] deformed, bool absolute) {
        import nulib.math : min;
        
        size_t m = min(deformPoints.length, deformed.length);
        if (absolute)
            deformPoints[0..m] = deformed[0..m];
        else
            deformPoints[0..m] += deformed[0..m];
    }

    /**
        Resets the deformation for the IDeformable.
    */
    abstract void resetDeform();

    /**
        Rescans the children of the deformer.
    */
    void rescan() {
        toDeform.length = 0;
        foreach(child; children) {
            this.scanPartsRecurse(child);
        }
    }
}