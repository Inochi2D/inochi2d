/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.draw.blending;
import numem.all;

/**
    Blending modes
*/
enum BlendMode : ubyte {
    
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