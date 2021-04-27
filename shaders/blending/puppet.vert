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
out vec2 screenCoords;

void main() {
    vec4 sverts = mvp * vec4(verts.x, verts.y, 0, 1);

    gl_Position = sverts;
    screenCoords = vec2((sverts.x+1)/2, (sverts.y+1)/2);
    
    texUVs = uvs;
}