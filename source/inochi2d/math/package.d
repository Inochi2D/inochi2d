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
V dampen(V)(V pos, V target, double delta, double speed = 1) if(is_vector!V) {
    return (pos - target) * pow(0.00000001, delta) + target;
}

/**
    Smoothly dampens from a position to a target
*/
float dampen(float pos, float target, double delta, double speed = 1) {
    return (pos - target) * pow(0.00000001, delta*speed) + target;
}

/**
    Gets whether a point is within an axis aligned rectangle
*/
bool contains(vec4 a, vec2 b) {
    return  b.x >= a.x && 
            b.y >= a.y &&
            b.x <= a.x+a.z &&
            b.y <= a.y+a.w;
}

/**
    Checks if 2 lines segments are intersecting
*/
bool areLineSegmentsIntersecting(vec2 p1, vec2 p2, vec2 p3, vec2 p4) {
    float epsilon = 0.00001f;
    float demoninator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y);
    if (demoninator == 0) return false;

    float uA = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / demoninator;
    float uB = ((p2.x - p1.x) * (p1.y - p3.y) - (p2.y - p1.y) * (p1.x - p3.x)) / demoninator;
    return (uA > 0+epsilon && uA < 1-epsilon && uB > 0+epsilon && uB < 1-epsilon);
}