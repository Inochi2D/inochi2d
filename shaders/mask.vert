/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
uniform mat4 mvpModel;
uniform mat4 mvpView;
uniform mat4 mvpProjection;
uniform vec2 offset;
layout(location = 0) in vec2 verts;

out vec2 texUVs;

void main() {
    gl_Position = mvpProjection * mvpView * mvpModel * vec4(verts.x-offset.x, verts.y-offset.y, 0, 1);
}