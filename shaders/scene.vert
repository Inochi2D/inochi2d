/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
uniform mat4 mvpModel;
uniform mat4 mvpView;
uniform mat4 mvpProjection;

layout(location = 0) in vec2 verts;
layout(location = 1) in vec2 uvs;

out vec2 texUVs;

void main() {
    vec3 vpos = vec3(verts.x, verts.y, 0);
    gl_Position = mvpProjection * mvpView * mvpModel * vec4(vpos, 1.0);
    texUVs = uvs;
}