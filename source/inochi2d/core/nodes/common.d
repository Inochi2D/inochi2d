/*
    Inochi2D Common Data

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.common;
import bindbc.opengl;

/**
    Blending modes
*/
enum BlendMode {
    // Normal blending mode
    Normal,

    // Multiply blending mode
    Multiply,
    
    // Color Dodge
    ColorDodge,

    // Linear Dodge
    LinearDodge,

    // Screen
    Screen
}

void inSetBlendMode(BlendMode blendingMode) {
    switch(blendingMode) {
        case BlendMode.Normal: 
            glBlendEquation(GL_FUNC_ADD);
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;
        case BlendMode.Multiply: 
            glBlendEquation(GL_FUNC_ADD);
            glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA); break;
        case BlendMode.ColorDodge:
            glBlendEquation(GL_FUNC_ADD);
            glBlendFunc(GL_DST_COLOR, GL_ONE); break;
        case BlendMode.LinearDodge:
            glBlendEquation(GL_FUNC_ADD);
            glBlendFunc(GL_ONE, GL_ONE); break;
        case BlendMode.Screen:
            glBlendEquation(GL_FUNC_ADD);
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR); break;
        default: assert(0);
    }
}
