/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.draw.cmd;
import inochi2d.core.blending;
import numem.all;
import inmath;

/**
    Texture reference
*/
alias InTexture = void*;

/**
    A rendering target
*/
alias InRenderTarget = void*;

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
    A drawing command, equating to one draw call sent to the GPU.
*/
struct DrawCommand {
@nogc:
    /**
        Clipping rectangle to be applied
    */
    rect clippingRect;

    /**
        Texture to be bound in drawing command
    */
    InTexture texture;

    /**
        Render target of draw command, null if main framebuffer.
    */
    InRenderTarget target;

    /**
        State of the stencil buffer.
    */
    StencilState stencilState;

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