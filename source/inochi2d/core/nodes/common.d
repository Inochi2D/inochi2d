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
    extern(C) void function() glBlendBarrierKHR;
}

void inInitBlending() {
    GLint extensionCount;
    glGetIntegerv(GL_NUM_EXTENSIONS, &extensionCount);
    foreach(i; 0..extensionCount) {
        string ext = cast(string)glGetStringi(GL_EXTENSIONS, i).fromStringz;

        // KHR blending extension
        if (ext == "GL_KHR_blend_equation_advanced") inAdvancedBlending = true;
        if (ext == "GL_KHR_blend_equation_advanced_coherent") inAdvancedBlendingCoherent = true;

        if (inAdvancedBlending && inAdvancedBlendingCoherent) break;
    }

    if (inAdvancedBlendingCoherent) glEnable(0x9285); // BLEND_ADVANCED_COHERENT_KHR && BLEND_ADVANCED_COHERENT_NV
    else {
        inAdvancedBlendingCoherent = false;
        
        debug {
            import std.stdio : writeln;
            if (inAdvancedBlending) writeln("Advanced blending is supported, but non-coherent blending is not available.");
        }
        inAdvancedBlending = false;
    }
    
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

// KHR blending
enum GL_MULTIPLY_KHR = 0x9294;
enum GL_SCREEN_KHR = 0x9295;
enum GL_OVERLAY_KHR = 0x9296;
enum GL_DARKEN_KHR = 0x9297;
enum GL_LIGHTEN_KHR = 0x9298;
enum GL_COLORDODGE_KHR = 0x9299;
enum GL_COLORBURN_KHR = 0x929A;
enum GL_HARDLIGHT_KHR = 0x929B;
enum GL_SOFTLIGHT_KHR = 0x929C;
enum GL_DIFFERENCE_KHR = 0x929E;
enum GL_EXCLUSION_KHR = 0x92A0;

void inSetBlendMode(BlendMode blendingMode) {
    if (!inAdvancedBlending) {
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
                glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ONE); break;
                
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
    } else {
        switch(blendingMode) {
            case BlendMode.Normal: 
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;

            case BlendMode.Multiply: glBlendEquation(GL_MULTIPLY_KHR); break;
            case BlendMode.Screen: glBlendEquation(GL_SCREEN_KHR); break;
            case BlendMode.Overlay: glBlendEquation(GL_OVERLAY_KHR); break;
            case BlendMode.Darken: glBlendEquation(GL_DARKEN_KHR); break;
            case BlendMode.Lighten: glBlendEquation(GL_LIGHTEN_KHR); break;
            case BlendMode.ColorDodge: glBlendEquation(GL_COLORDODGE_KHR); break;
            case BlendMode.LinearDodge:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ONE); break;
                
            case BlendMode.AddGlow:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFuncSeparate(GL_ONE, GL_ONE, GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;

            case BlendMode.ColorBurn: glBlendEquation(GL_COLORBURN_KHR); break;
            case BlendMode.HardLight: glBlendEquation(GL_HARDLIGHT_KHR); break;
            case BlendMode.SoftLight: glBlendEquation(GL_SOFTLIGHT_KHR); break;
            case BlendMode.Difference: glBlendEquation(GL_DIFFERENCE_KHR); break;
            case BlendMode.Exclusion: glBlendEquation(GL_EXCLUSION_KHR); break;

            case BlendMode.Subtract:
                glBlendEquationSeparate(GL_FUNC_REVERSE_SUBTRACT, GL_FUNC_ADD);
                glBlendFunc(GL_ONE, GL_ONE); break;

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
            
            default: assert(0);
        }
    }
}

void inBlendModeBarrier() {
    
    // TODO: bindbc-opengl needs to support KHR_blend_equation_advanced
    // Before we can have non-coherent blending
    // if (inAdvancedBlending && !inAdvancedBlendingCoherent) glBlendBarrierKHR();
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