/*
    Multiply Blending

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
#version 330
in vec2 texUVs;
in vec4 screenCoords;
out vec4 outColor;

uniform sampler2D tex;
uniform sampler2D screen;
uniform float threshold;
uniform float opacity;

vec3 blend(vec3 dst, vec4 src) {
    float _opacity = (src.a*opacity);
    return (dst*src.rgb) * _opacity + dst * (1.0-_opacity);
}

void main() {

    vec4 dst = texture(screen, screenCoords.xy); // Background
    vec4 src = texture(tex, texUVs); // Foreground

    // Discard any pixels that less opaque than our threshold
    if (src.a < threshold) discard;

    // Set the color if it passes our threshold test
    float falpha = src.a + dst.a * (1.0 - src.a);
    outColor = vec4(blend(dst.rgb, src), falpha);
}