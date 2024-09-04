/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.draw.cmd;
import inochi2d.core.draw.blending;
import numem.all;
import inmath;

/**
    Texture reference
*/
alias InTexture = void*;

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
        Texture to be bound in drawing command
    */
    InTexture source;

    /**
        Render target of draw command, null if main framebuffer.
    */
    InTexture target;

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
    size_t idxOffset;

    /**
        Vertex offset
    */
    size_t vtxOffset;

    /**
        Amount of elements to draw.
    */
    size_t drawCount;
}