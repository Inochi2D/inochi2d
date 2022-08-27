/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
in vec2 texUVs;

uniform sampler2D albedo;
uniform sampler2D emissive;
uniform sampler2D bumpmap;

uniform float opacity;
uniform vec3 multColor;
uniform vec3 screenColor;

layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outEmissive;
layout(location = 2) out vec4 outBump;

void main() {
    // Sample texture
    vec4 texColor = texture(albedo, texUVs);

    // Screen color math
    vec3 screenOut = vec3(1.0) - ((vec3(1.0)-(texColor.xyz)) * (vec3(1.0)-(screenColor*texColor.a)));
    
    // Multiply color math + opacity application.
    outAlbedo = vec4(screenOut.xyz, texColor.a) * vec4(multColor.xyz, 1) * opacity;

    // Emissive
    outEmissive = vec4(texture(emissive, texUVs).xyz, 1) * outAlbedo.a;
    float ee = clamp(outEmissive.r+outEmissive.g+outEmissive.b, 0, 1);
    if (ee == 0) outEmissive = vec4(0, 0, 0, 0);

    // Bumpmap
    outBump = vec4(texture(bumpmap, texUVs).xyz, 1) * outAlbedo.a;
    ee = clamp(outBump.r+outBump.g+outBump.b, 0, 1);
    if (ee == 0) outBump = vec4(0, 0, 0, 0);
}