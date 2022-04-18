/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
in vec2 texUVs;
out vec4 outColor;

uniform sampler2D tex;
uniform float threshold;

void main() {
    vec4 color = texture(tex, texUVs);
    if (color.a <= threshold) discard;
    outColor = vec4(1, 1, 1, 1);
}