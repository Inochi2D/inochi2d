/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
in vec2 texUVs;

layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outEmissive;
layout(location = 2) out vec4 outBump;

uniform vec3 ambientLight;
uniform vec2 fbSize;

uniform sampler2D albedo;
uniform sampler2D emissive;
uniform sampler2D bumpmap;

const int samples = 35;
const float sigma = float(samples) * 0.25;

// Gaussian
float gaussian(vec2 i) {
    return exp(-0.5*dot(i /= sigma, i)) / (6.28*sigma*sigma);
}

// Bloom texture by blurring it
vec4 bloom(sampler2D sp, vec2 uv, vec2 scale) {
    vec4 out_ = vec4(0);
    int s = samples/2;
    
    for ( int i = 0; i < s*s; i++ ) {
        vec2 d = vec2(i%s, i/s)*4.0 - float(samples)/2.0;
        out_ += gaussian(d) * texture( sp, uv + scale * d);
    }
    
    return out_ / out_.a;
}

void main() {

    // Bloom
    outEmissive = texture(emissive, texUVs) + bloom(emissive, texUVs, 1.0/fbSize);

    // Set color to the corrosponding pixel in the FBO
    vec4 light = clamp(
        vec4(ambientLight, 1) + 
        outEmissive,
        0, 1
    );

    outAlbedo = (texture(albedo, texUVs)*light);
    outBump = texture(bumpmap, texUVs);
}