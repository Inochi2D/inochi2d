/*
    Inochi2D Common Data

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.common;
import bindbc.opengl;
import inochi2d.fmt.serialize;

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
    Screen,

    // Lighten
    Lighten,

    // Exclusion
    Exclusion,

    // Subtract
    Subtract,

    // Inverse
    Inverse,

    // Clip to Lower
    // Special blending mode that clips the drawable
    // to a lower rendered area.
    ClipToLower,

    // Slice from Lower
    // Special blending mode that slices the drawable
    // via a lower rendered area.
    // Basically inverse ClipToLower
    SliceFromLower
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
            glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ONE); break;
        case BlendMode.Subtract:
            glBlendEquationSeparate(GL_FUNC_REVERSE_SUBTRACT, GL_FUNC_ADD);
            glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ONE); break;
        case BlendMode.Screen:
            glBlendEquation(GL_FUNC_ADD);
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR); break;
        case BlendMode.Lighten:
            glBlendEquation(GL_MAX);
            glBlendFunc(GL_ONE, GL_ONE); break;
        case BlendMode.Exclusion:
            glBlendEquation(GL_FUNC_ADD);
            glBlendFuncSeparate(GL_ONE_MINUS_DST_COLOR, GL_ONE_MINUS_SRC_COLOR, GL_ONE, GL_ONE); break;
        case BlendMode.Inverse:
            glBlendEquation(GL_FUNC_ADD);
            glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA); break;
        case BlendMode.ClipToLower:
            glBlendEquation(GL_FUNC_ADD);
            glBlendFunc(GL_DST_ALPHA, GL_ONE_MINUS_SRC_ALPHA); break;
        case BlendMode.SliceFromLower:
            glBlendEquation(GL_FUNC_ADD);
            glBlendFunc(GL_ZERO, GL_ONE_MINUS_SRC_ALPHA); break;
        default: assert(0);
    }
}

/**
    Masking mode
*/
enum MaskingMode {

    /**
        The part should be masked by the drawables specified
    */
    Mask,

    /**
        The path should be dodge masked by the drawables specified
    */
    DodgeMask
}

/**
    A binding between a mask and a mode
*/
struct MaskBinding {
public:
    import inochi2d.core.nodes.drawable : Drawable;
    @Name("source")
    uint maskSrcUUID;

    @Name("mode")
    MaskingMode mode;
    
    @Ignore
    Drawable maskSrc;
}