/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
in vec2 texUVs;
out vec4 outColor;

uniform sampler2D tex;
uniform float threshold = 0.01;

void main() {

    // Get color from texture
    vec4 color = texture(tex, texUVs);

    // Discard any pixels that less opaque than our threshold
    if (color.a < threshold) discard;

    // Set the color if it passes our threshold test
    outColor = color;
}