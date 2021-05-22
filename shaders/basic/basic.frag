/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
in vec2 texUVs;
out vec4 outColor;

uniform sampler2D fbo;
uniform float opacity;

void main() {
    outColor = texture(fbo, texUVs) * vec4(1, 1, 1, opacity);
}