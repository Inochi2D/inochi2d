/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
uniform mat4 modelViewMatrix;

layout(location = 0) in vec2 verts;
layout(location = 1) in vec2 uvs;

out vec2 texUVs;
out vec2 ndcTexCoords;

void main() {
    vec4 vertexCoords = modelViewMatrix * vec4(verts.x, verts.y, 0, 1);
    texUVs = uvs;

    // Normalized device coordinates go from -1..+1,
    // but texture sampling goes from 0..1, so we need to
    // remap the ndc coordinates to texture coordinates.
    ndcTexCoords = (vertexCoords.xy * 0.5 + vertexCoords.w * 0.5) / vertexCoords.w;
    gl_Position = vertexCoords;
}
