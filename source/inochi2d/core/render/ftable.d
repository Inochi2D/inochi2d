module inochi2d.core.render.ftable;
import inochi2d.core.render;
import inochi2d.core.texture;
import inochi2d.fmt;
import core.atomic;

private __gshared {
    InRendererFuncTable* _inFuncTable;
    size_t _inAllocModels;
}

package(inochi2d) {
    /// Adds a reference in the renderer
    void inRenderAddRef() {
        atomicFetchAdd(_inAllocModels, 1);
    }

    /// Removes a reference in the renderer
    void inRenderUnRef() {
        if (atomicLoad(_inAllocModels) > 0) atomicFetchSub(_inAllocModels, 1);
    }
}

/**
    Function pointer table for rendering operations
*/
struct InRendererFuncTable {
extern(C) nothrow:

    // REQUIRED: Setup
    bool function() isThreadsafe;
    bool function() construct;
    bool function() destruct;

    // REQUIRED: Textures
    void* function(ubyte* data, uint width, uint height, uint channels) allocateTexture;
    void* function(ubyte* data, ulong length, uint width, uint height, uint fmt) allocateTextureCompressed; /// NOTE: Not implemented as of current. as such it's optional
    void function(void* ptr) deallocateTexture;
    bool function(void* texture, ubyte** data, ulong* length) getTextureData;
    bool function(ubyte* data) cleanupTextureData;

    // REQUIRED: Nodes
    void function(InRID rid, InRenderData* data) finalizeNode;
    bool function(InRID rid, InRenderData* data) updateNode;
    void function(InRID rid, InRenderData* data) cleanupNode;

    // REQUIRED: SCENE INTEROP
    bool function(InRID rid, InRenderData* data) submit;
    bool function() beginScene;
    bool function() endScene;
    void function(int* x, int* y, uint* w, uint* h) getViewport;
    void function(int x, int y, uint w, uint h) setViewport;
    void* function(uint idx) getFramebufferView;
}

extern(C) nothrow:

/**
    Submits data for rendering to Inochi2D

    RETURNS: True if submission succeeded, false otherwise.
*/
bool inRenderSubmit(InRID rid, InRenderData* data) {
    if (_inFuncTable) {
        return _inFuncTable.submit(rid, data);
    }
    return false;
}

/**
    Finalizes a node's render specific data
*/
void inRenderNodeFinalize(InRID rid, InRenderData* data) {
    if (_inFuncTable) {
        _inFuncTable.finalizeNode(rid, data);
    }
}

/**
    Updates a node's render specific data

    RETURNS: true if the update succeeded, false otherwise.
*/
bool inRenderNodeUpdate(InRID rid, InRenderData* data) {
    if (_inFuncTable) {
        return _inFuncTable.updateNode(rid, data);
    }
    return false;

}

/**
    Cleans up a node's render specific data
*/
void inRenderNodeCleanup(InRID rid, InRenderData* data) {
    if (_inFuncTable) {
        _inFuncTable.cleanupNode(rid, data);
    }
}


/**
    Gets the framebuffer view (texture) for the specified index

    RETURNS: API Specific value as a void pointer.
    RETURNS: null if the index is invalid.
    RETURNS: null if the function table is not set up.
*/
void* inRenderGetFramebufferView(uint idx) {
    if (_inFuncTable) {
        return _inFuncTable.getFramebufferView(idx);
    }
    return null;
}

/**
    Gets the viewport in pixels. 
    
    NOTE: Coordinates start in the top left corner
*/
void inRenderGetViewport(int* x, int* y, uint* w, uint* h) {
    if (_inFuncTable) {
        _inFuncTable.getViewport(x, y, w, h);
    }
}

/**
    Sets the viewport in pixels. 
    
    NOTE: Coordinates start in the top left corner
*/
void inRenderSetViewport(int x, int y, uint w, uint h) {
    if (_inFuncTable) {
        _inFuncTable.setViewport(x, y, w, h);
    }
}

/**
    Gets whether the current renderer is threadsafe.

    There can only be one active renderer per application.
*/
bool inRenderIsThreadsafe() {
    if (_inFuncTable) {
        return _inFuncTable.isThreadsafe();
    }
    return false;
}

/**
    Gets the data for a texture,
    returns true if this was possible, otherwise false.
*/
bool inRenderGetTextureData(void* texture, ubyte** data, ulong* length) {
    if (_inFuncTable) {
        // TODO: Handle stream compressed textures
        return _inFuncTable.getTextureData(texture, data, length);
    }
    return false;
}
/**
    Cleans up the data for a texture,
    returns true if this was possible, otherwise false.
*/
bool inRenderCleanupTextureData(ubyte* data) {
    if (_inFuncTable) {
        // TODO: Handle stream compressed textures
        return _inFuncTable.cleanupTextureData(data);
    }
    return false;
}

/**
    Allocates texture
*/
void* inRenderAllocateTexture(ref TextureData data, uint channels) {
    if (_inFuncTable) {
        // TODO: Handle stream compressed textures
        return _inFuncTable.allocateTexture(data.data.ptr, data.width, data.height, channels);
    }
    return null;
}

/**
    Deallocates texture
*/
void inRenderDeallocateTexture(void* texture) {
    if (_inFuncTable) {
        return _inFuncTable.deallocateTexture(texture);
    }
}

/**
    Sets the active renderer

    Returns true if a renderer was set, returns false if otherwise
*/
bool inRenderSet(InRendererFuncTable* ftable) {
    if (!_inFuncTable) {
        if (ftable.construct()) {
            _inFuncTable = ftable;
            return true;
        }
    }

    return false;
}

/**
    Destroys the current renderer.

    NOTE: The renderer can not be destroyed while Puppets are referencing it.
    NOTE: In some instances there may be dangling pointers to objects, 
          any attempts to use those will lead to a segfault.
          Ensure you destroy all old data before changing the renderer.
*/
bool inRenderDestruct() {
    if (_inFuncTable) {
        if (inRenderRefs() == 0) {
            bool destroyed = _inFuncTable.destruct();
            if (destroyed) _inFuncTable = null;
            return destroyed;
        }
    }
    return false;
}

/**
    Begins rendering to the scene
*/
bool inRenderBeginScene() {
    return _inFuncTable.beginScene();
}

/**
    Ends rendering to the scene
*/
bool inRenderEndScene() {
    return _inFuncTable.endScene();
}

/**
    Updates node
*/
bool inRenderUpdateNode(InRID rid, ref InRenderData* data) {
    return _inFuncTable.updateNode(rid, data);
}

/**
    Returns how many Puppet objects are referencing the renderer.

    The renderer can not be changed unless this value is 0.
*/
size_t inRenderRefs() {
    return atomicLoad(_inAllocModels);
}