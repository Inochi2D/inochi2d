/*
    Inochi2D Rendering

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core;

public import inochi2d.core.render;
public import inochi2d.core.nodes;
public import inochi2d.core.puppet;
public import inochi2d.core.mesh;
public import inochi2d.core.param;
public import inochi2d.core.animation;
public import inochi2d.core.format;
public import inochi2d.core.phys;
public import inochi2d.core.guid;


import inochi2d.core.math;
import std.stdio;

/**
    UDA for sub-classable parts of the spec
    eg. Nodes and Automation can be extended by
    adding new subclasses that aren't in the base spec.
*/
struct TypeId { string id; }

/**
    Different modes of interpolation between values.
*/
enum InterpolateMode {

    /**
        Round to nearest
    */
    Nearest,
    
    /**
        Linear interpolation
    */
    Linear,

    /**
        Round to nearest
    */
    Stepped,

    /**
        Cubic interpolation
    */
    Cubic,

    /**
        Interpolation using beziér splines
    */
    Bezier,

    COUNT
}
