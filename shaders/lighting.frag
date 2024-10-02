/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
in vec2 texUVs;
in vec3 viewPosition;
in vec3 fragPosition;

layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outEmissive;
layout(location = 2) out vec4 outBump;

uniform vec3 ambientLight;
uniform vec3 ambientShadow;
uniform vec3 lightDirection;
uniform vec2 fbSize;

uniform sampler2D albedo;
uniform sampler2D emissive;
uniform sampler2D bumpmap;
uniform int LOD = 2;
uniform int samples = 25;

// Gaussian
float gaussian(vec2 i, float sigma) {
    return exp(-0.5*dot(i /= sigma, i)) / (6.28*sigma*sigma);
}

// Bloom texture by blurring it
vec4 bloom(sampler2D sp, vec2 uv, vec2 scale) {
    float sigma = float(samples) * 0.25;
    vec4 out_ = vec4(0);
    int sLOD = 1 << LOD;
    int s = samples/sLOD;
    
    for ( int i = 0; i < s*s; i++ ) {
        vec2 d = vec2(i%s, i/s)*float(sLOD) - float(samples)/2.0;
        out_ += gaussian(d, sigma) * textureLod( sp, uv + scale * d, LOD);
    }
    
    return out_ / out_.a;
}

// Normal mapping using blinn-phong
// This function takes a light and shadow color
// This allows coloring the shadowed parts.
vec4 normalMapping(sampler2D sp, vec2 uv, vec4 albedo, vec4 light, vec4 shadow) {
    vec3 viewDir = normalize(viewPosition - fragPosition);
    vec3 halfwayDir = normalize(lightDirection + viewDir);

    vec3 normal = texture(sp, uv).rgb;
    normal = normalize((normal * 2.0) - 1.0);
    
    // Callculate diffuse factor
    float diff = max(dot(normal, lightDirection), 0.0);
    vec3 diffuse = diff * light.xyz;
    
    // Calculate specular factor.
    float spec = pow(max(dot(normal, halfwayDir), 0.0), 2.0);
    vec3 specular = light.xyz * spec;

    // Calculate the object color
    vec4 objectColor = vec4((light.xyz + diffuse + specular), 1.0) * albedo;

    // Mix between the shadow color and calculated light
    // via linear interpolation
    return mix(albedo * shadow, objectColor, diff);
}

void main() {

    // Bloom
    outEmissive = texture(emissive, texUVs)+bloom(emissive, texUVs, 1.0/fbSize);

    // Set color to the corrosponding pixel in the FBO
    vec4 light = vec4(ambientLight, 1) + outEmissive;

    outAlbedo = normalMapping(bumpmap, texUVs, texture(albedo, texUVs), light, vec4(ambientShadow, 1.0));
    outBump = texture(bumpmap, texUVs);
}