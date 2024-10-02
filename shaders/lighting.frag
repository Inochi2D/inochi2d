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
uniform vec3 lightColor;
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
vec4 normalMapping(vec3 bump, vec4 albedo, vec3 light, vec3 ambientLight) {
    vec3 lightDir = vec3(lightDirection.xy, clamp(-lightDirection.z, -1, 1));
    vec3 viewDir = vec3(0, 0, -1);
    vec3 halfwayDir = normalize(lightDir + viewDir);
    vec3 normal = normalize((bump * 2.0) - 1.0);

    // Callculate diffuse factor
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = light * diff;
    
    // Calculate specular factor.
    float spec = pow(max(dot(normal, halfwayDir), 0.0), 0.5);
    vec3 specular = light * spec;

    // Calculate the object color
    vec4 objectColor = vec4((ambientLight + diffuse + specular), 1.0) * albedo;

    // Mix between the shadow color and calculated light
    // via linear interpolation
    return vec4(objectColor.rgb, albedo.a);
}

void main() {

    // Bloom
    outEmissive = texture(emissive, texUVs)+bloom(emissive, texUVs, 1.0/fbSize);
    outBump = texture(bumpmap, texUVs);

    vec4 albedo = texture(albedo, texUVs);
    vec4 emission = albedo * outEmissive;
    vec4 bump = normalMapping(outBump.rgb, albedo, lightColor, ambientLight);

    vec4 final = vec4((bump + emission).rgb, bump.a);
    outAlbedo = final;
}