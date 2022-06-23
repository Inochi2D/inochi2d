/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
in vec2 texUVs;
out vec4 outColor;

uniform sampler2D tex;
uniform float opacity;
uniform vec3 multColor;
uniform vec3 screenColor;

void main() {
    // Sample texture
    vec4 texColor = texture(tex, texUVs);

    // Screen color math
    vec3 screenOut = vec3(1.0) - ((vec3(1.0)-(texColor.xyz)) * (vec3(1.0)-(screenColor*texColor.a)));
    
    // Multiply color math + opacity application.
    outColor = vec4(screenOut.xyz, texColor.a) * vec4(multColor.xyz, 1) * opacity;
}