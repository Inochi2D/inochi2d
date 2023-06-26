/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen

    ADVANCED BLENDING - STAGE 1
*/
#version 330

// Advanced blendig mode enable
#ifdef GL_KHR_blend_equation_advanced 
#extension GL_KHR_blend_equation_advanced : enable
#endif

#ifdef GL_ARB_sample_shading
#extension GL_ARB_sample_shading : enable
#endif

in vec2 texUVs;

// Handle layout qualifiers for advanced blending specially
#ifdef GL_KHR_blend_equation_advanced 
    layout(blend_support_all_equations) out;
    layout(location = 0) out vec4 outAlbedo;
#else
    layout(location = 0) out vec4 outAlbedo;
#endif

uniform sampler2D albedo;

uniform float opacity;
uniform vec3 multColor;
uniform vec3 screenColor;

void main() {
    // Sample texture
    vec4 texColor = texture(albedo, texUVs);

    // Screen color math
    vec3 screenOut = vec3(1.0) - ((vec3(1.0)-(texColor.xyz)) * (vec3(1.0)-(screenColor*texColor.a)));
    
    // Multiply color math + opacity application.
    outAlbedo = vec4(screenOut.xyz, texColor.a) * vec4(multColor.xyz, 1) * opacity;
}