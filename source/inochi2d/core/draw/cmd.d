/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.draw.cmd;
import inochi2d.core.draw.blending;
import inochi2d.core.draw.render;
import numem.all;
import inmath;

/**
    Command types
*/
enum CommandType {
    /// Command is drawing
    Draw,

    /// Commanding is blitting framebuffers
    Blit
}

/**
    State of the stencil buffer
*/
enum StencilState {
    /**
        Stencil is turned off
    */
    Off,

    /**
        Stencil on, is cleared and is being filled
    */
    Fill,

    /**
        Stenciling is turned on.
    */
    On
}

/**
    Flags to be set.
*/
enum DrawFlags : uint {

    /// Nothing special should be performed
    None = 0x00,

    /// Tells the render backend to clear the render target.
    ClearTarget = 0x01,
}

/**
    A drawing command, equating to one draw call sent to the GPU.
*/
struct DrawCommand {
@nogc:
    CommandType type;

    /**
        Clipping rectangle to be applied
    */
    rect clippingRect;

    /**
        How many textures (max 3) that is being rendered from
    */
    uint renderSources;

    /**
        Texture to be bound in drawing command
    */
    InResourceID[3] source;

    /**
        Render target of draw command, null if main framebuffer.
    */
    InResourceID target;

    /**
        State of the stencil buffer.
    */
    StencilState stencilState;

    /**
        Drawing flags.
    */
    DrawFlags flags;

    /**
        Blending mode to be set for this command.
    */
    BlendMode blending;

    /**
        Index offset
    */
    uint idxOffset;

    /**
        Vertex offset
    */
    uint vtxOffset;

    /**
        Amount of elements to draw.
    */
    uint drawCount;
}