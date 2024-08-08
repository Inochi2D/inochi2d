/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.commands;
import inochi2d.core.blending;
import numem.all;

/// A Inochi2D Render ID.
alias RenderID = uint;

/**
    Render ID used when there's no target for a render command.
*/
enum RID_NONE = 0;

/**
    A render command.
*/
struct RenderCommand {
@nogc:

    /**
        The command being executed.
    */
    RCID commandId;

    /**
        The target (if any)
    */
    RenderID target;

    union {

        /**
            Data for mesh submission
        */
        UpdateMeshCommand updateMesh;
        
        /**
            Data for drawing operation
        */
        DrawCommand draw;
    }
}

/**
    Data for mesh submission
*/
struct UpdateMeshCommand {
@nogc:
    
    /**
        Buffer index in the case multiple buffers are present.
    */
    uint bufferIdx;

    /**
        Vertex data to submit.

        The memory is owned by Inochi2D and should not be freed.
    */
    float* data;

    /**
        Length of the data.
    */
    size_t length;

    /**
        Offset into the destination buffer
    */
    size_t offset;
}

/**
    Data for drawing operation
*/
struct DrawCommand {
@nogc:
    
    /**
        Whether drawing should happen to the stencil buffer
        instead of the color buffer.
    */
    bool drawToStencil = false;
    
    /**
        Whether the target buffer should be cleared.
        Depending on whether toStencil is enabled,
        this may clear the color or the stencil buffer.
    */
    bool clearBackingBuffer = false;

    /**
        The blending mode to be used for the rendering operation
    */
    BlendMode blending;
}

/**
    Render command IDs
*/
enum RCID : uint {
    /**
        Command has been marked as invalid by the command queue and should be skipped.
        Attempting to interpret an invalid command will lead to undefined behaviour.
    */
    invalidCommand  = 0,

    /**
        Submit a mesh for a RenderID.

        This mesh will be the result of CPU-side deformation and transformation.
    */
    updateMesh      = 1,

    /**
        Draws the first mesh for a RenderID.
    */
    draw            = 2,

    /**
        Enables the stencil buffer
    */
    startMask       = 4,

    /**
        Disables the stencil buffer
    */
    stopMask        = 5,

    /**
        Draws the contents of a framebuffer in the framebuffer stack
        to the framebuffer one level below.
        
        If the framebuffer stack is at level 1, drawing will be done to the output framebuffer.
    */
    drawFramebufferContents = 6,

    /**
        Pushes a framebuffer to the framebuffer stack.
    */
    pushFramebuffer = 7,

    /**
        Pops a framebuffer from the framebuffer stack.
    */
    popFramebuffer  = 8,
}