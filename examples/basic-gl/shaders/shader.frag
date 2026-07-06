/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 420
in vec2 texUVs;
in vec2 ndcTexCoords;

layout(location = 0) out vec4 outAlbedo;
layout(binding = 0) uniform sampler2D albedo;

void main() {
    outAlbedo = texture(albedo, texUVs);
}
