/*
    Inochi2D Spline Group

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.pathdeform;
import inochi2d.core.nodes;
import inochi2d.math;

/**
    A node that deforms multiple nodes against a path.
*/
class PathDeform : Node {
public:
    /**
        The joints of the deformation
    */
    mat3[] joints;

    /**
        The bindings from joints to verticies in multiple parts

        [Part] = Every part that is affected
        [] = the entry of the joint
        size_t[] = the entry of verticies in that part that should be affected.
    */
    size_t[][][Part] bindings;

    /**
        Updates the spline group.
    */
    override
    void update() {


        super.update();
    }
}