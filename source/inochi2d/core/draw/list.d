module inochi2d.core.draw.list;
import inochi2d.core.draw.cmd;
import numem.all;

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

            // Move all indices one step back
            prevIndiceCount[0..IN_DRAW_COMPACT_READINGS] = prevIndiceCount[1..IN_DRAW_COMPACT_READINGS+1];
        }

        // Setup step.
        {
            // NOTE: numem vectors will not free memory when length is changed
            // without calls to shrinkToFit. This allows reusing the memory
            // using the append operator, which is safer.
            commands.length = 0;
            vertices.length = 0;
            indices.length = 0;
        }
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
        size_t vtxOffset = this.vertices.size();
        size_t idxOffset = this.indices.size();

        this.vertices ~= vertices;
        this.indices ~= indices;
    
        ret.vtxOffset = vtxOffset;
        ret.idxOffset = idxOffset;
        ret.drawCount = indices.length;

        return ret;
    }

    /**
        Finalize a drawing command, pushing it to this frame's draw list.
    */
    void submit(DrawCommand command) {

        // Don't allow invalid render commands.
        if (command.vtxOffset >= this.vertices.size()) return;
        if (command.idxOffset >= this.indices.size()) return;
        if (command.idxOffset + command.drawCount > this.indices.size()) return;
        if (command.texture is null) return;

        commands ~= command;
    }
}