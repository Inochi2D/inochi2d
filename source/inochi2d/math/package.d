/*
    Inochi2D Math helpers

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.math;
import gl3n.util;
public import gl3n.linalg;
public import gl3n.math;
public import std.math : isNaN;
public import gl3n.interpolate;

public import inochi2d.math.transform;
public import inochi2d.math.camera;

// Unsigned int vectors
alias vec2u = Vector!(uint, 2); /// ditto
alias vec3u = Vector!(uint, 3); /// ditto
alias vec4u = Vector!(uint, 4); /// ditto

// Unsigned short vectors
alias vec2us = Vector!(ushort, 2); /// ditto
alias vec3us = Vector!(ushort, 3); /// ditto
alias vec4us = Vector!(ushort, 4); /// ditto

/**
    Smoothly dampens from a position to a target
*/
V dampen(V)(V pos, V target, float delta, float speed = 1) if(is_vector!V) {
    return (pos - target) * pow(1e-4f, delta*speed) + target;
}
/**
    Smoothly dampens from a position to a target
*/
float dampen(float pos, float target, float delta, float speed = 1) {
    return (pos - target) * pow(1e-4f, delta*speed) + target;
}