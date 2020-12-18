/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
uniform mat4 mvp;
layout(location = 0) in vec2 verts;
layout(location = 1) in vec2 uvs;

out vec2 texUVs;
out vec4 screenCoords;

void main() {
    screenCoords = mvp * vec4(verts.x, verts.y, 0, 1);
    gl_Position = screenCoords;
    texUVs = uvs;
}