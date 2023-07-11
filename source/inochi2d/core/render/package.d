/*
    Inochi2D Rendering

    Copyright © 2023, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.render;
import inochi2d.core.render.texture;
import inochi2d.core.nodes;
import inochi2d.core.texture;
import std.exception;
import core.sync.mutex;

package(inochi2d) {
    // Inochi2D renderer for this thread
    static InochiRenderer inThreadRenderer;

    // Global Inochi2D renderer shared between threads
    __gshared InochiRenderer inSharedRenderer;
}

/**
    Gets the instantiated renderer for this thread.

    If a threadsafe global renderer is present the threadsafe 
    renderer will be returned instead.
*/
ref InochiRenderer inRendererGetForThisThread() {
    if (inSharedRenderer) return inSharedRenderer;
    return inThreadRenderer;
}

/**
    Initializes a renderer for thread local use. 


*/
void inRendererInit(InochiRenderer renderer) {
    enforce(!inSharedRenderer, "Can't create thread-local renderer when global renderer exists.");

    // Destroy existing renderer if any exists.
    if (inThreadRenderer) {
        inThreadRenderer.dispose();
    }

    // Create new renderer
    renderer.create(false);
    inThreadRenderer = renderer;
}

/**
    Initializes a renderer for global threadsafe use. 

    A renderer needs to be capable of threadsafe operation,
    see `InochiRenderer.isRendererThreadsafeCapable`.
*/
void inRendererInitGlobal(InochiRenderer renderer) {
    enforce(renderer.isRendererThreadsafeCapable(), "Renderer is not threadsafe capable!");

    // Destroy existing renderer if any exists.
    if (inSharedRenderer) {
        inThreadRenderer.dispose();
    }

    // Create new renderer
    renderer.create(true);
    inSharedRenderer = renderer;
}

/**
    Destroys the renderer for the current thread if it exists.
    returns whether a renderer was destroyed.
*/
bool inRendererDestroy() {
    if (inThreadRenderer) {
        inThreadRenderer.dispose();
        destroy!false(inThreadRenderer);
        inThreadRenderer = null;
        return true;
    }
    return false;
}

/**
    Destroys the global threadsafe renderer if it exists.
    returns whether a renderer was destroyed.
*/
bool inRendererDestroyGlobal() {
    if (inSharedRenderer) {
        inSharedRenderer.dispose();
        destroy!false(inSharedRenderer);
        inSharedRenderer = null;
        return true;
    }
    return false;
}
/**
    Renderer resource data
*/
struct RendererResource {
    string tag;
    void* resourcePointer;
}

/**
    A renderer implementation
*/
abstract
class InochiRenderer {
private:
    // Mutex for resources
    Mutex resourceMutex;

    /// List of resource pointers managed by this renderer.
    RendererResource*[] resources;
    
    // Mutex for resources
    Mutex textureMutex;

    /// List of textures managed by this renderer.
    Texture[] textures;

protected:

    /**
        Allocates a resource
    */
    RendererResource* allocResource(T)(string tag) {

        RendererResource* res = new RendererResourceData(tag, new T);

        // Add to local resource cache
        resourceMutex.lock();
            resources ~= res;
        resourceMutex.unlock();

        // Return resource
        return res;
    }

    /**
        Deallocates a resource
    */
    final
    void deallocResource(RendererResource* ptr, bool stopManaging=true) {
        import std.algorithm.searching : countUntil;
        import std.algorithm.mutation : remove;

        // Lock resources, find and remove resource.
        resourceMutex.lock();
            ptrdiff_t ptrpos = resources.countUntil(ptr);

            if (ptrpos >= 0) {

                // Clear data
                *resources[ptrpos] = RendererResource.init;

                // If the item should stop being managed, remove it from the list
                if (stopManaging) resources = resources.remove(ptrpos);
            }
        resourceMutex.unlock();
    }

    /**
        Instantiates all rendering state
    */
    abstract void create(bool threadsafeRequested);

    /**
        Cleans up all renderering state
    */
    abstract void dispose();

    /**
        Creates resources for a node and sets the RendererResource item in the node
    */
    abstract RendererResource createResourcesFor(Node node);
    
    /**
        Destroys resources for a node and nulls the RendererResource item in the node
    */
    abstract void destroyResourcesFor(Node node);

    /**
        Destroys the specified resource data

        This function should free all GPU side data for the resource
        a tag is provided to allow you to use a switch statement
        to handle it.
    */
    abstract void destroyResourceData(RendererResourceData* data, bool stopManaging=true);

    /**
        Handle node pre-draw
    */
    abstract void onPreDraw(Node node);

    /**
        Handle node draw
    */
    abstract void onDraw(Node node);

    /**
        Handle node post-draw
    */
    abstract void onPostDraw(Node node);

public:
    ~this() {
        this.dispose();
    }

    /**
        Gets whether this renderer can safely be called from
        another thread.

        Note that a renderer may be made in a threadsafe API
        but created in a thread unsafe fashion.
    */
    abstract bool isRendererThreadsafe();

    /**
        Gets whether the renderer is capable of being instantiated
        for threadsafe use.
    */
    abstract bool isRendererThreadsafeCapable();

    /**
        Creates a texture from a TextureData object
    */
    abstract Texture createTexture(TextureData data);

    /**
        Gets the maximum level of anisotropy
    */
    abstract float getMaxAnisotropy();

    /**
        Sets the viewport
    */
    abstract void getViewport(out int width, out int height);

    /**
        Sets the viewport
    */
    abstract void setViewport(int width, int height);

    /**
        Gets the clear color
    */
    abstract void getClearColor(out float r, out float g, out float b, out float a);

    /**
        Sets the clear color
    */
    abstract void setClearColor(float r, float g, float b, float a);

    /**
        Begins rendering the scene
    */
    abstract void beginScene();

    /**
        Ends rendering the scene
    */
    abstract void endScene();

    /**
        Draws the scene
    */
    abstract void drawScene();

    /**
        Sets whether post-processing should be enabled
    */
    abstract bool setPostprocess(bool state);

    /**
        Gets the ambient lighting color
    */
    abstract void getAmbientLightColor(out float r, out float g, out float b);

    /**
        Sets the ambient lighting
    */
    abstract void setAmbientLightColor(float r, float g, float b);

    /**
        Creates a texture from a file

        When channels is set to 0 the channel count will be 
        based of the contents of the file.
    */
    final
    Texture createTexture(string file, int channels=0) {
        return createTexture(TextureData(file, channels));
    }
    
    /**
        Destroys all resources associated with this renderer.

        Returns true if anything was destroyed
    */
    final
    bool destroyAllResources() {
        int c = 0;

        // Clear all resources
        resourceMutex.lock();
            foreach(ref resource; resources) {
                this.destroyResourceData(resource);
                c++;
            }
            resources.length = 0;
        resourceMutex.unlock();

        return c > 0;
    }

    /**
        Destroys all textures associated with this renderer.

        Returns true if anything was destroyed
    */
    final
    bool destroyAllTextures() {
        int c = 0;

        // Clear all textures
        textureMutex.lock();
            foreach(ref texture; textures) {
                texture.dispose();
                c++;
            }
            textures.length = 0;
        textureMutex.unlock();

        return c > 0;
    }

    /**
        Destroys all rendering state
    */
    final
    void destroyAll() {
        this.destroyAllResources();
        this.destroyAllTextures();
    }
}

/**
    Begins a Inochi2D rendering pass
*/
void inBeginScene() {
    inRendererGetForThisThread().beginScene();
}

/**
    Ends a Inochi2D rendering pass
*/
void inEndScene() {
    inRendererGetForThisThread().endScene();
}

/**
    Draw scene to area
*/
void inDrawScene(vec4 area) {
    inRendererGetForThisThread().drawScene(area);
}

/**
    Sets the viewport area to render to
*/
void inSetViewport(int width, int height) nothrow {
    inRendererGetForThisThread().setViewport(width, height);
}

/**
    Gets the viewport
*/
void inGetViewport(out int width, out int height) nothrow {
    inRendererGetForThisThread().getViewport(width, height);
}

/**
    Sets the background clear color
*/
void inSetClearColor(float r, float g, float b, float a) nothrow {
    inRendererGetForThisThread().setClearColor(r, g, b, a);
}

/**
    Gets the clear color
*/
void inGetClearColor(out float r, out float g, out float b, out float a) nothrow {
    inRendererGetForThisThread().getClearColor(r, g, b, a);
}