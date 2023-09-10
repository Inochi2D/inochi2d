module inochi2d.core.render.ftable;
import inochi2d.core.render;
import inochi2d.core.texture;

private __gshared {
    InRendererFuncTable _inFuncTable;
}

/**
    Function pointer table for rendering operations
*/
struct InRendererFuncTable {
extern(C):
    void function(InRID rid, ref InRenderData) finalizeNode;
    void function(InRID rid, ref InRenderData) cleanupNode;

    bool function() construct;
    bool function() destruct;

    bool function() beginScene;
    bool function() endScene;
    bool function(InRID rid, ref InRenderData) updateNode;
    bool function(InRID rid, InRenderData) submit;
}

/**
    Sets the active renderer

    Returns true if a renderer was set, returns false if otherwise
*/
bool inRenderSet(InRendererFuncTable ftable) {
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