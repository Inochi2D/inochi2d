/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 120
#extension GL_ARB_explicit_attrib_location : require
uniform mat4 mvp;
layout(location = 0) in vec3 verts;

varying vec2 texUVs;

void main() {
    gl_Position = mvp * vec4(verts.x, verts.y, verts.z, 1);
}