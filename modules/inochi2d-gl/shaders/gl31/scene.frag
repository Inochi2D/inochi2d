/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
in vec2 texUVs;
out vec4 outColor;

uniform sampler2D fbo;

void main() {
    // Set color to the corrosponding pixel in the FBO
    vec4 color = texture(fbo, texUVs);
    outColor = vec4(color.r, color.g, color.b, color.a);
}