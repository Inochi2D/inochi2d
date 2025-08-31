/*
    Inochi2D Common Data

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.common;
import inochi2d.core.format;

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

BlendMode toBlendMode(string name) {
    switch(name) with(BlendMode) {
        default: return Normal;
        case "Multiply": return Multiply;
        case "Screen": return Screen;
        case "Overlay": return Overlay;
        case "Darken": return Darken;
        case "Lighten": return Lighten;
        case "ColorDodge": return ColorDodge;
        case "LinearDodge": return LinearDodge;
        case "AddGlow": return AddGlow;
        case "ColorBurn": return ColorBurn;
        case "HardLight": return HardLight;
        case "SoftLight": return SoftLight;
        case "Difference": return Difference;
        case "Exclusion": return Exclusion;
        case "Subtract": return Subtract;
        case "Inverse": return Inverse;
        case "DestinationIn": return DestinationIn;
        case "ClipToLower": return ClipToLower;
        case "SliceFromLower": return SliceFromLower;
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

MaskingMode toMaskingMode(string name) {
    switch(name) with(MaskingMode) {
        default: return Mask;
        case "Mask": return Mask;
        case "DodgeMask": return DodgeMask;
    }
}

/**
    A binding between a mask and a mode
*/
struct MaskBinding {
public:
    import inochi2d.core.nodes.drawable : Drawable;
    uint maskSrcUUID;

    MaskingMode mode;
    
    Drawable maskSrc;


    /**
        Serialization function
    */
    void onSerialize(ref JSONValue object) {
        object["uuid"] = maskSrcUUID;
        object["mode"] = mode;
    }

    /**
        Deserialization function
    */
    void onDeserialize(ref JSONValue object) {
        object.tryGetRef(maskSrcUUID, "uuid");
        mode = object.tryGet!string("mode").toMaskingMode;
    }
}