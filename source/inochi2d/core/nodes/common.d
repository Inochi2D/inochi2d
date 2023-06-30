/*
    Inochi2D Common Data

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.common;
import bindbc.opengl;
import inochi2d.fmt.serialize;
import bindbc.opengl.context;
import std.string;

private {
    bool inAdvancedBlending;
    bool inAdvancedBlendingCoherent;

    void inSetBlendModeLegacy(BlendMode blendingMode) {
        switch(blendingMode) {
            
            // If the advanced blending extension is not supported, force to Normal blending
            default:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;

            case BlendMode.Normal: 
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;

            case BlendMode.Multiply: 
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA); break;

            case BlendMode.Screen:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR); break;

            case BlendMode.Lighten:
                glBlendEquation(GL_MAX);
                glBlendFunc(GL_ONE, GL_ONE); break;

            case BlendMode.ColorDodge:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_DST_COLOR, GL_ONE); break;

            case BlendMode.LinearDodge:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_COLOR, GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;
                
            case BlendMode.AddGlow:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFuncSeparate(GL_ONE, GL_ONE, GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;

            case BlendMode.Subtract:
                glBlendEquationSeparate(GL_FUNC_REVERSE_SUBTRACT, GL_FUNC_ADD);
                glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ONE); break;

            case BlendMode.Exclusion:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFuncSeparate(GL_ONE_MINUS_DST_COLOR, GL_ONE_MINUS_SRC_COLOR, GL_ONE, GL_ONE); break;

            case BlendMode.Inverse:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA); break;
            
            case BlendMode.DestinationIn:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ZERO, GL_SRC_ALPHA); break;

            case BlendMode.ClipToLower:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_DST_ALPHA, GL_ONE_MINUS_SRC_ALPHA); break;

            case BlendMode.SliceFromLower:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ZERO, GL_ONE_MINUS_SRC_ALPHA); break;
        }
    }
}

/**
    Whether a multi-stage rendering pass should be used for blending
*/
bool inUseMultistageBlending(BlendMode blendingMode) {
    switch(blendingMode) {
        case BlendMode.Normal,
             BlendMode.LinearDodge,
             BlendMode.AddGlow,
             BlendMode.Subtract,
             BlendMode.Inverse,
             BlendMode.DestinationIn,
             BlendMode.ClipToLower,
             BlendMode.SliceFromLower:
                 return false;
        default: return hasKHRBlendEquationAdvanced;
    }
}

void inInitBlending() {
    
    if (hasKHRBlendEquationAdvanced) inAdvancedBlending = true;
    if (hasKHRBlendEquationAdvancedCoherent) inAdvancedBlendingCoherent = true;
    if (inAdvancedBlendingCoherent) glEnable(GL_BLEND_ADVANCED_COHERENT_KHR);
}

/*
    INFORMATION ABOUT BLENDING MODES
    Blending is a complicated topic, especially once we get to mobile devices and games consoles.

    The following blending modes are supported in Standard mode:
        Normal
        Multiply
        Screen
        Overlay
        Darken
        Lighten
        Color Dodge
        Linear Dodge
        Add (Glow)
        Color Burn
        Hard Light
        Soft Light
        Difference
        Exclusion
        Subtract
        Inverse
        Destination In
        Clip To Lower
        Slice from Lower
    Some of these blending modes behave better on Tiling GPUs.

    The following blending modes are supported in Core mode:
        Normal
        Multiply
        Screen
        Lighten
        Color Dodge
        Linear Dodge
        Add (Glow)
        Inverse
        Destination In
        Clip to Lower
        Slice from Lower
    Tiling GPUs on older mobile devices don't have great drivers, we shouldn't tempt fate.
*/

/**
    Blending modes
*/
enum BlendMode {
    // Normal blending mode
    Normal,

    // Multiply blending mode
    Multiply,

    // Screen
    Screen,

    // Overlay
    Overlay,

    // Darken
    Darken,

    // Lighten
    Lighten,
    
    // Color Dodge
    ColorDodge,

    // Linear Dodge
    LinearDodge,

    // Add (Glow)
    AddGlow,

    // Color Burn
    ColorBurn,

    // Hard Light
    HardLight,

    // Soft Light
    SoftLight,

    // Difference
    Difference,

    // Exclusion
    Exclusion,

    // Subtract
    Subtract,

    // Inverse
    Inverse,

    // Destination In
    DestinationIn,

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

bool inIsAdvancedBlendMode(BlendMode mode) {
    if (!inAdvancedBlending) return false;
    switch(mode) {
        case BlendMode.Multiply:
        case BlendMode.Screen: 
        case BlendMode.Overlay: 
        case BlendMode.Darken: 
        case BlendMode.Lighten: 
        case BlendMode.ColorDodge: 
        case BlendMode.ColorBurn: 
        case BlendMode.HardLight: 
        case BlendMode.SoftLight: 
        case BlendMode.Difference: 
        case BlendMode.Exclusion: 
            return true;
        
        // Fallback to legacy
        default: 
            return false;
    }
}

void inSetBlendMode(BlendMode blendingMode, bool legacyOnly=false) {
    if (!inAdvancedBlending || legacyOnly) inSetBlendModeLegacy(blendingMode);
    else switch(blendingMode) {
        case BlendMode.Multiply: glBlendEquation(GL_MULTIPLY_KHR); break;
        case BlendMode.Screen: glBlendEquation(GL_SCREEN_KHR); break;
        case BlendMode.Overlay: glBlendEquation(GL_OVERLAY_KHR); break;
        case BlendMode.Darken: glBlendEquation(GL_DARKEN_KHR); break;
        case BlendMode.Lighten: glBlendEquation(GL_LIGHTEN_KHR); break;
        case BlendMode.ColorDodge: glBlendEquation(GL_COLORDODGE_KHR); break;
        case BlendMode.ColorBurn: glBlendEquation(GL_COLORBURN_KHR); break;
        case BlendMode.HardLight: glBlendEquation(GL_HARDLIGHT_KHR); break;
        case BlendMode.SoftLight: glBlendEquation(GL_SOFTLIGHT_KHR); break;
        case BlendMode.Difference: glBlendEquation(GL_DIFFERENCE_KHR); break;
        case BlendMode.Exclusion: glBlendEquation(GL_EXCLUSION_KHR); break;
        
        // Fallback to legacy
        default: inSetBlendModeLegacy(blendingMode); break;
    }
}

void inBlendModeBarrier(BlendMode mode) {
    if (inAdvancedBlending && !inAdvancedBlendingCoherent && inIsAdvancedBlendMode(mode)) 
        glBlendBarrierKHR();
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