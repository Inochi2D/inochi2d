/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330

out vec2 texUVs;

vec2 verts[6] = vec2[](
    vec2(-1, -1),
    vec2(-1, 1),
    vec2(1, -1),
    
    vec2(1, -1),
    vec2(-1, 1),
    vec2(1, 1)
);

vec2 uvs[6] = vec2[](
    vec2(0, 0),
    vec2(0, 1),
    vec2(1, 0),
    
    vec2(1, 0),
    vec2(0, 1),
    vec2(1, 1)
);

void main() {
    gl_Position = vec4(verts[gl_VertexID], 0, 1);
    texUVs = uvs[gl_VertexID];
}