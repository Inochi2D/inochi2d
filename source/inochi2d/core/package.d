/*
    Inochi2D Rendering

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core;

public import inochi2d.core.texture;
public import inochi2d.core.nodes;
public import inochi2d.core.puppet;
public import inochi2d.core.meshdata;
public import inochi2d.core.param;
public import inochi2d.core.automation;
public import inochi2d.core.animation;
public import inochi2d.core.render;
public import inochi2d.core.render.texture;
public import inochi2d.integration;

import bindbc.opengl;
import inochi2d.math;
import std.stdio;

version(Windows) {
    // Ask Windows nicely to use dedicated GPUs :)
    export extern(C) int NvOptimusEnablement = 0x00000001;
    export extern(C) int AmdPowerXpressRequestHighPerformance = 0x00000001;
}

private {
    static Camera inCamera;
}

/**
    Gets the global camera
*/
Camera inGetCamera() {
    return inCamera;
}

/**
    Sets the global camera, allows switching between cameras
*/
void inSetCamera(Camera camera) {
    inCamera = camera;
}

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
