module inochi2d.core.render.ftable;
import inochi2d.core.render;
import inochi2d.core.texture;
import inochi2d.fmt;

private __gshared {
    InRendererFuncTable* _inFuncTable;
}

/**
    Function pointer table for rendering operations
*/
struct InRendererFuncTable {
extern(C):

    /// REQUIRED
    bool function() isThreadsafe;
    bool function() construct;
    bool function() destruct;

    void* function(ubyte* data, uint width, uint height, uint channels) allocateTexture;
    void function(void* ptr) deallocateTexture;
    bool function(void* texture, ubyte** data, ulong* length) getTextureData;
    bool function(ubyte* data) cleanupTextureData;

    void function(InRID rid, ref InRenderData) finalizeNode;
    void function(InRID rid, ref InRenderData) cleanupNode;

    bool function() beginScene;
    bool function() endScene;
    bool function(InRID rid, ref InRenderData) updateNode;
    bool function(InRID rid, InRenderData) submit;

    /// NOTE: Not implemented as of current.
    void* function(ubyte* data, ulong length, uint width, uint height, uint fmt) allocateTextureCompressed;
}

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
    Destroys the current renderer, 
*/
bool inRenderDestruct() {
    if (_inFuncTable) {
        return _inFuncTable.destruct();
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
bool inRenderUpdateNode(InRID rid, ref InRenderData data) {
    return _inFuncTable.updateNode(rid, data);
}

/**
    Renders node
*/
bool inRenderSubmit(InRID rid, InRenderData data) {
    return _inFuncTable.submit(rid, data);
}