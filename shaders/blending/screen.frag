/*
    Screen Blending

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

float _screen(float bg, float fg) {
    return 1.0-((1.0-bg)*(1.0-fg));
}

vec3 blend(vec3 bg, vec4 fg) {
    float _opacity = (fg.a*opacity);
    return vec3(_screen(bg.r, fg.r), _screen(bg.g, fg.g), _screen(bg.b, fg.b)) * _opacity + bg * (1.0-_opacity);
}

void main() {

    // Background = the thing we're blending to (framebuffer)
    // Foreground = the thing we're blending with (DynMesh texture)

    vec4 bg = texture(screen, screenCoords.xy); // Background
    vec4 fg = texture(tex, texUVs); // Foreground

    // Discard any pixels that less opaque than our threshold
    if (fg.a < threshold) discard;

    // Set the color if it passes our threshold test
    outColor = vec4(blend(bg.rgb, fg.rgb), clamp(bg.a+fg.a, 0, 1));
}