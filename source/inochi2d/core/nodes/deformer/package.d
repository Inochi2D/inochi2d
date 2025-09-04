/*
    Inochi2D Deformers

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.deformer;
import inochi2d.core.nodes;
import inochi2d.core.math;

public import inochi2d.core.nodes.deformer.meshdeformer;
public import inochi2d.core.nodes.deformer.latticedeformer;

/**
    A node which deforms the vertex data of nodes beneath
    it.

    Deformations happen in world space
*/
abstract
class Deformer : Node, IDeformable {
public:

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
}