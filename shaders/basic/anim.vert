/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
uniform mat4 mvp;
uniform vec2 offset;

layout(location = 0) in vec2 verts;
layout(location = 1) in vec2 uvs;
layout(location = 2) in vec2 deform;

uniform vec2 splits;
uniform float animation;
uniform float frame;

out vec2 texUVs;

void main() {
    gl_Position = mvp * vec4(verts.x-offset.x+deform.x, verts.y-offset.y+deform.y, 0, 1);
    texUVs = vec2((uvs.x/splits.x)*frame, (uvs.y/splits.y)*animation);
}