/**
    Inochi2D DrawList Interface

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.render.drawlist;
import inochi2d.core.render.state;
import inmath;
import nulib;
import numem;
import inochi2d.core.render.texture;
import inochi2d.core.nodes.common;
import inochi2d.core.mesh;

/**
    A draw list containing the rendering state and commands
    to submit to the GPU.
*/
final
class DrawList : NuObject {
private:
@nogc:

    // Working set
    DrawListAlloc           _call;
    DrawCmd                 _ccmd;

    // Draw Commands
    vector!DrawCmd          _cmds;
    uint                    _cmdp;

    // Vertex Data
    vector!VtxData          _vtxs;
    uint                    _vtxp;

    // Index Data
    vector!uint             _idxs;
    uint                    _idxp;

    // Buffer allocations
    vector!DrawListAlloc    _allocs;
    uint                    _allp;

    // Stacks
    stack!(Texture[IN_MAX_ATTACHMENTS]) _targetsStack;

public:

    /**
        Whether to use base vertex specification.
    */
    bool useBaseVertex = true;

    /**
        Command Buffer
    */
    @property DrawCmd[] commands() => _cmds[0.._cmdp];

    /**
        Vertex data
    */
    @property VtxData[] vertices() => _vtxs[0.._vtxp];

    /**
        Index data
    */
    @property uint[] indices() => _idxs[0.._idxp];

    /**
        Allocates the given mesh in the draw list, allowing its
        contents to be reused in draw commands.

        Params:
            vtx = Vertex data to push.
            idx = Index data to push.
    
        Returns:
            A reference to the drawlist allocation on success,
            $(D null) otherwise.
    */
    DrawListAlloc* allocate(VtxData[] vtx, uint[] idx) {
        
        // Invalid vertex buffer check.
        if (vtx.length < 3)
            return null;

        // Invalid index buffer check.
        if (idx.length != 0 && (idx.length % 3) != 0)
            return null;

        // Resize if stuff doesn't fit.
        if (_vtxp+vtx.length >= _vtxs.length)
            _vtxs.resize(_vtxp+vtx.length+1);
        if (_idxp+idx.length >= _idxs.length)
            _idxs.resize(_idxp+idx.length+1);

        // Meshes supply their own index data, as such
        // we offset it here to fit within our buffer.
        if (!useBaseVertex)
            idx[0..$] += _idxp;

        _vtxs[_vtxp.._vtxp+vtx.length] = vtx[0..$];
        _idxs[_idxp.._idxp+idx.length] = idx[0..$];
        _vtxp += vtx.length;
        _idxp += idx.length;

        _call.elemCount = cast(uint)idx.length;

        // Set up allocation.
        if (_allp >= _allocs.length)
            _allocs ~= _call;
        else
            _allocs[_allp] = _call;

        // prepare next alloc
        _call = DrawListAlloc.init;
        _call.idxOffset = _idxp;
        _call.vtxOffset = _vtxp;
        return &_allocs[_allp++];
    }

    /**
        Pushes render targets to the draw list's stack.
    */
    void pushTargets(Texture[IN_MAX_ATTACHMENTS] targets) {
        if (!_ccmd.isEmpty)
            this.next();
        
        _targetsStack.push(targets);
    }

    /**
        Sets sources for the current draw call.
    */
    void setSources(Texture[IN_MAX_ATTACHMENTS] sources) {
        _ccmd.sources = sources;
    }

    /**
        Sets the blending mode for the current draw call.
    */
    void setBlending(BlendMode blendMode) {
        _ccmd.blendMode = blendMode;
    }

    /**
        Sets the masking mode for the current draw call.
    */
    void setMasking(MaskingMode maskMode) {
        _ccmd.maskMode = maskMode;
    }

    /**
        Sets the mesh data for the current draw command.

        Params:
            alloc = The vertex allocation cookie.
    */
    void setMesh(DrawListAlloc* alloc) {
        if (!alloc) return;
        
        _ccmd.idxOffset = alloc.idxOffset;
        _ccmd.vtxOffset = alloc.vtxOffset;
        _ccmd.elemCount = alloc.elemCount;
    }

    /**
        Sets the active state for the current command.
    */
    void setDrawState(DrawState state) {
        _ccmd.state = state;
    }

    /**
        Pushes the next draw command
    */
    void next() {
        if (_ccmd.isEmpty)
            return;

        if (_cmdp >= _cmds.length)
            _cmds ~= _ccmd;
        else
            _cmds[_cmdp] = _ccmd;

        _cmdp++;

        if (!_targetsStack.empty)
            _targetsStack.tryPeek(0, _ccmd.targets);
    }

    /**
        Pops the top render target from the list's stack.
    */
    void popTargets() {
        if (!_ccmd.isEmpty)
            this.next();
        
        if (!_targetsStack.empty)
            _targetsStack.pop();
    }

    /**
        Clears the draw list, making it ready for a new pass.
    */
    void clear() {
        _vtxp = 0;
        _idxp = 0;
        _cmdp = 0;
        _allp = 0;
        _ccmd = DrawCmd.init;
        _call = DrawListAlloc.init;
        _targetsStack.clear();
    }
}

/**
    Maximum number of texture attachments.
*/
enum IN_MAX_ATTACHMENTS = 8;

/**
    An allocation within the drawlist
*/
struct DrawListAlloc {

    /**
        Vertex offset.
    */
    uint vtxOffset;

    /**
        Index offset.
    */
    uint idxOffset;

    /**
        Number of indices.
    */
    uint elemCount;
}

/**
    Draw state flags.
*/
enum DrawState : uint {

    /**
        Normal drawing.
    */
    normal = 0,

    /**
        A masking run is being defined.
    */
    defineMask = 1,

    /**
        Use the mask to draw the current command,
        reuse the mask if the next state also is
        maskedDraw.
    */
    maskedDraw = 2,
}

/**
    A drawing command that is sent to the GPU.
*/
struct DrawCmd {
@nogc:

    /**
        Render targets
    */
    Texture[IN_MAX_ATTACHMENTS] targets;

    /**
        Source textures
    */
    Texture[IN_MAX_ATTACHMENTS] sources;

    /**
        The current state of the drawing command.
    */
    DrawState state;

    /**
        Blending mode to apply
    */
    BlendMode blendMode;

    /**
        Masking mode to apply.
    */
    MaskingMode maskMode;

    /**
        Vertex offset.
    */
    uint vtxOffset;

    /**
        Index offset.
    */
    uint idxOffset;

    /**
        Number of indices.
    */
    uint elemCount;

    /**
        Whether the command is empty.
    */
    @property bool isEmpty() => elemCount == 0;
}