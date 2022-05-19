/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 120
varying vec2 texUVs;

uniform sampler2D fbo;

void main() {
    // Set color to the corrosponding pixel in the FBO
    vec4 color = texture2D(fbo, texUVs);
    gl_FragColor = vec4(color.r * color.a, color.g * color.a, color.b * color.a, color.a);
}