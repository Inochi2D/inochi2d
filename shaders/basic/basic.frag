/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
in vec2 texUVs;
in vec4 vertexCoord;

layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outEmissive;
layout(location = 2) out vec4 outBump;

uniform sampler2D albedo;
uniform sampler2D emissive;
uniform sampler2D bumpmap;

uniform mat4 mvpModel;
uniform mat4 mvpViewProjection;
uniform float opacity;
uniform vec3 multColor;
uniform vec3 screenColor;
uniform float emissionStrength = 1;

vec4 screen(vec3 tcol, float a) {
    return vec4(vec3(1.0) - ((vec3(1.0)-tcol) * (vec3(1.0)-(screenColor*a))), a);
}

void main() {
    // Sample texture
    vec4 texColor = texture(albedo, texUVs);
    vec4 emiColor = texture(emissive, texUVs);

    vec4 mult = vec4(multColor.xyz, 1);

    // Bumpmapping orientation
    vec4 origin = mvpModel * vec4(0, 0, 0, 1);
    vec4 bumpAngle = texture(bumpmap, texUVs) * 2.0 - 1.0;
    vec4 normal = mvpModel * (vec4(-bumpAngle.x, bumpAngle.yz, 1.0));
    normal = normalize(normal-origin) * 0.5 + 0.5;

    // Out color math
    vec4 albedoOut = screen(texColor.xyz, texColor.a) * mult;
    vec4 emissionOut = screen(emiColor.xyz, texColor.a) * mult * emissionStrength;
    
    // Albedo
    outAlbedo = albedoOut * opacity;

    // Emissive
    outEmissive = emissionOut * outAlbedo.a;

    // Bumpmap
    outBump = normal * outAlbedo.a;
}