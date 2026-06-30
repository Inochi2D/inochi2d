/**
    Inochi2D DrawList Interface

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.render.drawlist;
import inochi2d.core.render.state;
import inochi2d.core.render.texture;
import inochi2d.core.mesh;
import numath;
import nulib;
import numem;

/**
    A draw list containing the rendering state and commands
    to submit to the GPU.
*/
final
class DrawList : NuObject {
private:
@nogc:

    // Working set
    DrawListAlloc _call;
    DrawCmd _ccmd;

    // Draw Commands
    vector!DrawCmd _cmds;
    uint _cmdp;

    // Vertex Data
    vector!VtxData _vtxs;
    uint _vtxp;

    // Index Data
    vector!uint _idxs;
    uint _idxp;

    // Buffer allocations
    vector!DrawListAlloc _allocs;
    uint _allp;

    // Stacks
    stack!(Texture[IN_MAX_ATTACHMENTS]) _targetsStack;

public:

    // Destructor
     ~this() {
        _cmds.clear();
        _vtxs.clear();
        _idxs.clear();
        _allocs.clear();
        _targetsStack.clear();
    }

    /**
        Whether to use base vertex specification.
    */
    bool useBaseVertex = true;

    /**
        Command Buffer
    */
    @property DrawCmd[] commands() => _cmds[0 .. _cmdp];

    /**
        Vertex data
    */
    @property VtxData[] vertices() => _vtxs[0 .. _vtxp];

    /**
        Index data
    */
    @property uint[] indices() => _idxs[0 .. _idxp];

    /**
        Allocated meshes
    */
    @property DrawListAlloc[] allocations() => _allocs[0 .. _allp];

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
        if (idx.length < 3)
            return null;

        // Resize if stuff doesn't fit.
        if (_vtxp + vtx.length >= _vtxs.length)
            _vtxs.resize(_vtxp + vtx.length + 1);
        if (_idxp + idx.length >= _idxs.length)
            _idxs.resize(_idxp + idx.length + 1);

        // Meshes supply their own index data, as such
        // we offset it here to fit within our buffer.
        if (!useBaseVertex)
            idx[0 .. $] += _idxp;

        _vtxs[_vtxp .. _vtxp + vtx.length] = vtx[0 .. $];
        _idxs[_idxp .. _idxp + idx.length] = idx[0 .. $];
        _vtxp += vtx.length;
        _idxp += idx.length;

        _call.allocId = _allp;
        _call.idxCount = cast(uint)idx.length;
        _call.vtxCount = cast(uint)vtx.length;

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
    void beginComposite() {
        _ccmd.state = DrawState.compositeBegin;
        this.next();
    }

    /**
        Pops the top render target from the list's stack.
    */
    void endComposite() {
        _ccmd.state = DrawState.compositeEnd;
        this.next();
    }

    /**
        Enqueues a composite blit for a recently ended composite.
    */
    void blit() {
        _ccmd.state = DrawState.compositeBlit;
        this.next();
    }

    /**
        Pushes render targets to the draw list's stack.
    */
    void pushMask(MaskingMode mode) {
        _ccmd.state = DrawState.pushMask;
        _ccmd.maskMode = mode;
        this.next();
    }

    /**
        Pops the top render target from the list's stack.
    */
    void popMask() {
        _ccmd.state = DrawState.popMask;
        this.next();
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
    void setBlending(BlendMode value) {
        _ccmd.blendMode = value;
    }

    /**
        Sets the blending mode for the current draw call.
    */
    void setVariables(T)(uint nid, T value) if (T.sizeof <= _ccmd.variables.sizeof) {
        _ccmd.typeId = nid;
        nu_memcpy(_ccmd.variables.ptr, cast(void*)&value, T.sizeof);
    }

    /**
        Sets the masking mode for the current draw call.
    */
    void setMasking(MaskingMode value) {
        _ccmd.state = DrawState.defineMask;
        _ccmd.maskMode = value;
    }

    /**
        Sets the mesh data for the current draw command.

        Params:
            alloc = The vertex allocation cookie.
    */
    void setMesh(DrawListAlloc* alloc) {
        if (!alloc)
            return;

        _ccmd.allocId = alloc.allocId;
        _ccmd.idxOffset = alloc.idxOffset;
        _ccmd.vtxOffset = alloc.vtxOffset;
        _ccmd.elemCount = alloc.idxCount;
    }

    /**
        Pushes the next draw command
    */
    void next() {
        if (_cmdp >= _cmds.length)
            _cmds ~= _ccmd;
        else
            _cmds[_cmdp] = _ccmd;

        _cmdp++;
        _ccmd = DrawCmd.init;
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
    uint idxCount;

    /**
        Number of vertices.
    */
    uint vtxCount;

    /**
        Allocation ID.
    */
    uint allocId;
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
        Draws a mask source to the top level mask buffer.
    */
    defineMask = 1,

    /**
        Finalizes the current mask, then pushes it onto the stack.
    */
    pushMask = 2,

    /**
        Pops the current mask from the stack, restoring the higher level
        mask, or exits mask mode.
    */
    popMask = 3,

    /**
        A composition into composition textures
        has begun.
    */
    compositeBegin = 4,

    /**
        A composition into composition textures
        has ended.
    */
    compositeEnd = 5,

    /**
        Sources should be drawn to targets using
        the given blending mode.
    */
    compositeBlit = 6,
}

/**
    A drawing command that is sent to the GPU.
*/
struct DrawCmd {
@nogc:

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
        Allocation ID.
    */
    uint allocId;

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
        Type ID of the node being drawn.
    */
    uint typeId;

    /**
        Variables passed to the draw list.
    */
    void[64] variables;

    /**
        Whether the command is empty.
    */
    @property bool isEmpty() => elemCount == 0;
}
