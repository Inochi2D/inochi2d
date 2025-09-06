/**
    Inochi2D Render State

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.render.state;
import inmath;

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
enum BlendMode : uint {
    // Normal blending mode
    normal          = 0x00,

    // Multiply blending mode
    multiply        = 0x01,

    // Screen
    screen          = 0x02,

    // Overlay
    overlay         = 0x03,

    // Darken
    darken          = 0x04,

    // Lighten
    lighten         = 0x05,
    
    // Color Dodge
    colorDodge      = 0x06,

    // Linear Dodge
    linearDodge     = 0x07,

    // Add (Glow)
    addGlow         = 0x08,

    // Color Burn
    colorBurn       = 0x09,

    // Hard Light
    hardLight       = 0x0A,

    // Soft Light
    softLight       = 0x0B,

    // Difference
    difference      = 0x0C,

    // Exclusion
    exclusion       = 0x0D,

    // Subtract
    subtract        = 0x0E,

    // Inverse
    inverse         = 0x0F,

    // Destination In
    destinationIn   = 0x10,

    // Clip to Lower
    // Special blending mode that clips the drawable
    // to a lower rendered area.
    clipToLower     = 0x11,

    // Slice from Lower
    // Special blending mode that slices the drawable
    // via a lower rendered area.
    // Basically inverse ClipToLower
    sliceFromLower  = 0x12
}

BlendMode toBlendMode(string name) {
    switch(name) with(BlendMode) {
        default: return normal;
        case "Multiply": return multiply;
        case "Screen": return screen;
        case "Overlay": return overlay;
        case "Darken": return darken;
        case "Lighten": return lighten;
        case "ColorDodge": return colorDodge;
        case "LinearDodge": return linearDodge;
        case "AddGlow": return addGlow;
        case "ColorBurn": return colorBurn;
        case "HardLight": return hardLight;
        case "SoftLight": return softLight;
        case "Difference": return difference;
        case "Exclusion": return exclusion;
        case "Subtract": return subtract;
        case "Inverse": return inverse;
        case "DestinationIn": return destinationIn;
        case "ClipToLower": return clipToLower;
        case "SliceFromLower": return sliceFromLower;
    }
}

/**
    Masking mode
*/
enum MaskingMode : uint {

    /**
        The part should be masked by the drawables specified
    */
    mask = 0,

    /**
        The path should be dodge masked by the drawables specified
    */
    dodge = 1,
}

MaskingMode toMaskingMode(string name) {
    switch(name) {

        case "Mask":
        case "mask":
            return MaskingMode.mask;

        case "DodgeMask":
        case "dodgeMask":
            return MaskingMode.dodge;
        
        default:
            return MaskingMode.mask;
    }
}