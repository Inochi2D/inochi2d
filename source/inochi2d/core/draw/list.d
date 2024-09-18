/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.draw.list;
import inochi2d.core.draw.cmd;
import inochi2d.core.draw.render;
import numem.all;
import inmath;

/**
    Draw vertices

    TODO: Seperate UV and position for faster updates in normal use?
*/
struct DrawVertex {
    vec2 position;
    vec2 uv;
}

/**
    How many readings should be kept to determine when to compact
    the memory associated with the draw list.
*/
enum IN_DRAW_COMPACT_READINGS = 10;

/**
    The threshold at which the draw list will be compacted.
*/
enum IN_DRAW_COMPACT_THRESHOLD = 5;

/**
    How many vertices should be reserved initially.
*/
enum IN_DRAW_RESERVE = 10_000;

/**
    Draw List which keeps track of drawing commands.
*/
class DrawList {
@nogc:
private:
    vector!DrawCommand commands;

    // Vertex buffer
    vector!DrawVertex   vertices;

    // Index buffer
    vector!uint         indices;

    // Draw list compactor stats.
    size_t[IN_DRAW_COMPACT_READINGS+1] prevIndiceCount;

public:

    /**
        Destructor
    */
    ~this() {
        destroy(commands);
        destroy(vertices);
        destroy(indices);
    }

    /**
        Constructor
    */
    this() {

        // To optimize initial rendering before warmup,
        // we reserve enough memory for 10k vertices.
        this.vertices.reserve(IN_DRAW_RESERVE);

        // This will prevent compacting in the first IN_DRAW_COMPACT_READINGS frames.
        foreach(i; 0..prevIndiceCount.length) {
            prevIndiceCount[i] = size_t.max;
        }
    }


    /**
        Gets current draw commands in draw list.

        This should not be written to.
    */
    DrawCommand[] getDrawCommands() {
        return commands[0..$];
    }

    /**
        Gets current vertices in draw list

        This should not be written to.
    */
    DrawVertex[] getVertexBuffer() {
        return vertices[0..$];
    }

    /**
        Gets current vertices in draw list

        This should not be written to.
    */
    uint[] getIndexBuffer() {
        return indices[0..$];
    }

    /**
        Compacts the buffers
    */
    void compact() {
        commands.shrinkToFit();
        vertices.shrinkToFit();
        indices.shrinkToFit();
    }

    /**
        Begins a render pass.

        This is automatically called by the puppet when
        drawing is invoked for it.
    */
    void begin() {

        // Compacting step
        {
            // Determine how many times in the last few frames that the size
            // of the draw list was lower than it is currently.
            size_t lowerCount = 0;
            foreach(i; 0..IN_DRAW_COMPACT_READINGS-1) 
                if (prevIndiceCount[i] < prevIndiceCount[IN_DRAW_COMPACT_READINGS])
                    lowerCount++;

            // If below the compile-time set threshold, compact the memory to save space.
            if (lowerCount >= IN_DRAW_COMPACT_THRESHOLD) 
                this.compact();
        }

        // Setup step.
        {
            // NOTE: numem vectors will not free memory when length is changed
            // without calls to shrinkToFit. This allows reusing the memory
            // using the append operator, which is safer.
            commands.resize(0);
            vertices.resize(0);
            indices.resize(0);
        }
    }

    /**
        Ends a render pass
    */
    void end() {
        // Move all indices one step back
        prevIndiceCount[0..IN_DRAW_COMPACT_READINGS] = prevIndiceCount[1..IN_DRAW_COMPACT_READINGS+1];
        prevIndiceCount[IN_DRAW_COMPACT_READINGS] = indices.size();
    }

    /**
        Blits a source framebuffer to the targeted framebuffer.

        Remember to finalize the draw submission with the
        submit(DrawCommand) call.
    */
    DrawCommand blit(InResourceID source, InResourceID target) {
        DrawCommand ret;
        ret.type = CommandType.Blit;
        ret.source = source;
        ret.target = target;

        return ret;
    }

    /**
        Adds vertices and indices into the draw list and returns 
        a draw command ready to be filled out with supplementary
        render information.

        Remember to finalize the draw submission with the
        submit(DrawCommand) call.
    */
    DrawCommand draw(DrawVertex[] vertices, uint[] indices) {
        DrawCommand ret;

        // Get offset to beginning of data.
        uint vtxOffset = cast(uint)this.vertices.size();
        uint idxOffset = cast(uint)this.indices.size();

        this.vertices ~= vertices;
        this.indices ~= indices;
    
        ret.vtxOffset = vtxOffset;
        ret.idxOffset = idxOffset;
        ret.drawCount = cast(uint)indices.length;

        return ret;
    }

    /**
        Submit a command to the list, 
    */
    void submit(DrawCommand command) {

        // Error condition handling.
        switch(command.type) {

            case CommandType.Draw:
                // Don't allow invalid render commands.
                if (command.vtxOffset >= this.vertices.size()) return;
                if (command.idxOffset >= this.indices.size()) return;
                if (command.idxOffset + command.drawCount > this.indices.size()) return;
                if (command.source[0] is null) return;
                break;

            default:
                break;
        }

        commands ~= command;
    }
}