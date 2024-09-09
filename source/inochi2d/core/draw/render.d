/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.draw.render;
import inochi2d.core.draw.list;

/**
    Texture reference
*/
alias InResourceID = void*;

/**
    Functions which should be implemented by an Inochi2D renderer.
*/
struct RendererFunctions {
@nogc:
public extern(C):

    /**
        Called by the renderer during initialization.

        Should return the userData to be passed to subsequent function calls.
        The userData should be freed in shutdown.
    */
    void* function() initialize;

    /**
        Called by the renderer during shutdown.

        Remember to free the userData!
    */
    void function(void* userData) shutdown;

    /**
        Creates a texture
    */
    InResourceID function (void* userData, size_t width, size_t height) createTexture;

    /**
        Uploads data to texture
    */
    bool function(void* userData, InResourceID texture, ubyte* data, uint length) uploadTextureData;
    
    /**
        Destroys a texture
    */
    bool function (void* userData, InResourceID texture) destroyTexture;

    /**
        Creates a framebuffer
    */
    InResourceID function(void* userData, size_t width, size_t height) createFramebuffer;

    /**
        Destroys a framebuffer
    */
    bool function(void* userData, InResourceID fb) destroyFramebuffer;

    /**
        Called when a drawlist is requesting to be rendered.
    */
    bool function (void* userData, DrawList* drawList) renderList;
}

/**
    Inochi2D renderer interface.
*/
class Renderer {
@nogc:
private:
    RendererFunctions renderFuncs;
    void* userData;

public:

    /**
        Destructor
    */
    ~this() {
        this.renderFuncs.shutdown(userData);
    }

    /**
        Creates a new renderer with the specified rendering functions.
    */
    this(RendererFunctions funcs) {
        this.renderFuncs = funcs;
        this.userData = funcs.initialize();
    }

    /**
        Creates a texture
    */
    InResourceID createTexture(size_t width, size_t height) {
        return this.renderFuncs.createTexture(userData, width, height);
    }

    /**
        Uploads data to texture
    */
    bool uploadTextureData(InResourceID texture, ubyte* data, uint length) {
        return this.renderFuncs.uploadTextureData(userData, texture, data, length);
    }

    /**
        Destroys a texture
    */
    bool destroyTexture(InResourceID texture) {
        return this.renderFuncs.destroyTexture(userData, texture);
    }

    /**
        Creates a framebuffer
    */
    InResourceID createFramebuffer(size_t width, size_t height) {
        return this.renderFuncs.createFramebuffer(userData, width, height);
    }

    /**
        Destroys a framebuffer
    */
    bool destroyFramebuffer(InResourceID fb) {
        return this.renderFuncs.destroyFramebuffer(userData, fb);
    }

    /**
        Called when a drawlist is requesting to be rendered.
    */
    bool renderList (DrawList* drawList) {
        return this.renderFuncs.renderList(userData, drawList);
    }
}