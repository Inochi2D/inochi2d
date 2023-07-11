/*
    Inochi2D GL Renderer

    Copyright © 2023, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
deprecated("OpenGL backend will be moving to a seperate package in the future!")
module inochi2d.core.render.gl;
import inochi2d.core.render.gl.texture;
import inochi2d.core.render;
import bindbc.opengl;

class GLRenderer : InochiRenderer {
private:
    // Viewport
    int inViewportWidth;
    int inViewportHeight;

    // Scene Buffers
    GLuint sceneVAO;
    GLuint sceneVBO;

    // Framebuffer 0
    GLuint fBuffer;
    GLuint fAlbedo;
    GLuint fEmissive;
    GLuint fBump;
    GLuint fStencil;

    // Framebuffer 1
    GLuint cfBuffer;
    GLuint cfAlbedo;
    GLuint cfEmissive;
    GLuint cfBump;
    GLuint cfStencil;

    // Clear color
    vec4 clearColor;

    // Post processing
    bool postProcessEnabled;
    PostProcessingShader[] postProcessingStack;

    // Camera
    Camera camera;

    // Compositing state
    bool isCompositing;

    void runPostprocessingPass() {
        if (postProcessingStack.length == 0) return;
        
        bool targetBuffer;

        float r, g, b, a;
        inGetClearColor(r, g, b, a);

        // Render area
        vec4 area = vec4(
            0, 0,
            inViewportWidth, inViewportHeight
        );

        // Tell OpenGL the resolution to render at
        float[] data = [
            area.x,         area.y+area.w,          0, 0,
            area.x,         area.y,                 0, 1,
            area.x+area.z,  area.y+area.w,          1, 0,
            
            area.x+area.z,  area.y+area.w,          1, 0,
            area.x,         area.y,                 0, 1,
            area.x+area.z,  area.y,                 1, 1,
        ];
        glBindBuffer(GL_ARRAY_BUFFER, sceneVBO);
        glBufferData(GL_ARRAY_BUFFER, 24*float.sizeof, data.ptr, GL_DYNAMIC_DRAW);


        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, fEmissive);
        glGenerateMipmap(GL_TEXTURE_2D);

        // We want to be able to post process all the attachments
        glBindFramebuffer(GL_FRAMEBUFFER, cfBuffer);
        glDrawBuffers(3, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);
        glClear(GL_COLOR_BUFFER_BIT);

        glBindFramebuffer(GL_FRAMEBUFFER, fBuffer);
        glDrawBuffers(3, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);

        foreach(shader; postProcessingStack) {
            targetBuffer = !targetBuffer;

            if (targetBuffer) {

                // Main buffer -> Composite buffer
                glBindFramebuffer(GL_FRAMEBUFFER, cfBuffer); // dst
                renderScene(area, shader, fAlbedo, fEmissive, fBump); // src
            } else {

                // Composite buffer -> Main buffer 
                glBindFramebuffer(GL_FRAMEBUFFER, fBuffer); // dst
                renderScene(area, shader, cfAlbedo, cfEmissive, cfBump); // src
            }
        }

        if (targetBuffer) {
            glBindFramebuffer(GL_READ_FRAMEBUFFER, cfBuffer);
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fBuffer);
            glBlitFramebuffer(
                0, 0, inViewportWidth, inViewportHeight, // src rect
                0, 0, inViewportWidth, inViewportHeight, // dst rect
                GL_COLOR_BUFFER_BIT, // blit mask
                GL_LINEAR // blit filter
            );
        }
        
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }

    void renderScene(vec4 area, PostProcessingShader shaderToUse, GLuint albedo, GLuint emissive, GLuint bump) {
        glViewport(0, 0, cast(int)area.z, cast(int)area.w);

        // Bind our vertex array
        glBindVertexArray(sceneVAO);
        
        glDisable(GL_CULL_FACE);
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glBlendEquation(GL_FUNC_ADD);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

        shaderToUse.shader.use();
        shaderToUse.shader.setUniform(shaderToUse.getUniform("mvp"), 
            mat4.orthographic(0, area.z, area.w, 0, 0, max(area.z, area.w)) * 
            mat4.translation(area.x, area.y, 0)
        );

        // Ambient light
        GLint ambientLightUniform = shaderToUse.getUniform("ambientLight");
        if (ambientLightUniform != -1) shaderToUse.shader.setUniform(ambientLightUniform, inSceneAmbientLight);

        // framebuffer size
        GLint fbSizeUniform = shaderToUse.getUniform("fbSize");
        if (fbSizeUniform != -1) shaderToUse.shader.setUniform(fbSizeUniform, vec2(inViewportWidth, inViewportHeight));

        // Bind the texture
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, albedo);
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, emissive);
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, bump);

        // Enable points array
        glEnableVertexAttribArray(0); // verts
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4*float.sizeof, null);

        // Enable UVs array
        glEnableVertexAttribArray(1); // uvs
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4*float.sizeof, cast(float*)(2*float.sizeof));

        // Draw
        glDrawArrays(GL_TRIANGLES, 0, 6);

        // Disable the vertex attribs after use
        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);

        glDisable(GL_BLEND);
    }

protected:
    override 
    void create(bool threadsafeRequested) {

        // Set the viewport and by extension set the textures
        this.setViewport(640, 480);
        
        // Initialize dynamic meshes
        // inInitBlending();
        // inInitNodes();
        // inInitDrawable();
        // inInitPart();
        // inInitMask();
        // inInitComposite();
        // inInitMeshGroup();
        // version(InDoesRender) inInitDebug();

        // Some defaults that should be changed by app writer
        inCamera = new Camera;

        inClearColor = vec4(0, 0, 0, 0);
        // Shader for scene
        basicSceneShader = PostProcessingShader(new Shader(import("scene.vert"), import("scene.frag")));
        glGenVertexArrays(1, &sceneVAO);
        glGenBuffers(1, &sceneVBO);

        // Generate the framebuffer we'll be using to render the model and composites
        glGenFramebuffers(1, &fBuffer);
        glGenFramebuffers(1, &cfBuffer);
        
        // Generate the color and stencil-depth textures needed
        // Note: we're not using the depth buffer but OpenGL 3.4 does not support stencil-only buffers
        glGenTextures(1, &fAlbedo);
        glGenTextures(1, &fEmissive);
        glGenTextures(1, &fBump);
        glGenTextures(1, &fStencil);

        glGenTextures(1, &cfAlbedo);
        glGenTextures(1, &cfEmissive);
        glGenTextures(1, &cfBump);
        glGenTextures(1, &cfStencil);

        // Attach textures to framebuffer
        glBindFramebuffer(GL_FRAMEBUFFER, fBuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, fAlbedo, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, fEmissive, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, fBump, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, fStencil, 0);

        glBindFramebuffer(GL_FRAMEBUFFER, cfBuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, cfAlbedo, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, cfEmissive, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, cfBump, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, cfStencil, 0);

        // go back to default fb
        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        // Add post processing stack members
        postProcessingStack ~= PostProcessingShader(
            new Shader(
                import("scene.vert"),
                import("lighting.frag")
            )
        );
    }

    override
    void dispose() {
        
    }

    override
    RendererResource createResourcesFor(Node node) {
        return RendererResource.init; // TODO: implement
    }

    override
    void destroyResourcesFor(Node node) {
        
    }

    override
    void destroyResourceData(RendererResourceData* data, bool stopManaging = true) {
        
    }

    override
    void onPreDraw(Node node) {
        
    }

    override
    void onDraw(Node node) {
        
    }

    override
    void onPostDraw(Node node) {
        
    }

public:
    override 
    bool isRendererThreadsafe() {
        return false; // TODO: implement
    }

    override 
    bool isRendererThreadsafeCapable() { return false; }

    override 
    Texture createTexture(TextureData data) {
        return new GLTexture(data);
    }

    override 
    float getMaxAnisotropy() {
        float value;
        glGetFloatv(MAX_TEXTURE_MAX_ANISOTROPY_EXT, &value);
        return value;
    }
    
    override
    void getViewport(out int width, out int height) nothrow {
        width = inViewportWidth;
        height = inViewportHeight;
    }
    
    override
    void setViewport(int width, int height) {
        
    }
    
    override
    void getClearColor(out float r, out float g, out float b, out float a) {
        r = clearColor.r;
        g = clearColor.g;
        b = clearColor.b;
        a = clearColor.a;
    }
    
    override
    void setClearColor(float r, float g, float b, float a) {
        clearColor = vec4(r, g, b, a);
    }
    
    override
    void beginScene() {
        glBindVertexArray(sceneVAO);
        glEnable(GL_BLEND);
        glEnablei(GL_BLEND, 0);
        glEnablei(GL_BLEND, 1);
        glEnablei(GL_BLEND, 2);
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);

        // Make sure to reset our viewport if someone has messed with it
        glViewport(0, 0, inViewportWidth, inViewportHeight);

        // Bind and clear composite framebuffer
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, cfBuffer);
        glDrawBuffers(3, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);
        glClearColor(0, 0, 0, 0);

        // Bind our framebuffer
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fBuffer);

        // First clear buffer 0
        glDrawBuffers(1, [GL_COLOR_ATTACHMENT0].ptr);
        glClearColor(inClearColor.r, inClearColor.g, inClearColor.b, inClearColor.a);
        glClear(GL_COLOR_BUFFER_BIT);

        // Then clear others with black
        glDrawBuffers(2, [GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);
        glClearColor(0, 0, 0, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        // Everything else is the actual texture used by the meshes at id 0
        glActiveTexture(GL_TEXTURE0);

        // Finally we render to all buffers
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        glDrawBuffers(3, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);
    }
    
    override
    void endScene() {
        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        glDisablei(GL_BLEND, 0);
        glDisablei(GL_BLEND, 1);
        glDisablei(GL_BLEND, 2);
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_CULL_FACE);
        glDisable(GL_BLEND);
        glFlush();
        glDrawBuffers(1, [GL_COLOR_ATTACHMENT0].ptr);
    }
    
    override
    void beginComposite() {

        // We don't allow recursive compositing
        if (isCompositing) return;
        isCompositing = true;

        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, cfBuffer);
        glDrawBuffers(3, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);
        glClearColor(0, 0, 0, 0);
        glClear(GL_COLOR_BUFFER_BIT);

        // Everything else is the actual texture used by the meshes at id 0
        glActiveTexture(GL_TEXTURE0);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    }
    
    override
    void endComposite() {

        // We don't allow recursive compositing
        if (!isCompositing) return;
        isCompositing = false;

        glBindFramebuffer(GL_FRAMEBUFFER, fBuffer);
        glDrawBuffers(3, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);
        glFlush();
        
    }
    
    override
    void drawScene() {  
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        float[] data = [
            area.x,         area.y+area.w,          0, 0,
            area.x,         area.y,                 0, 1,
            area.x+area.z,  area.y+area.w,          1, 0,
            
            area.x+area.z,  area.y+area.w,          1, 0,
            area.x,         area.y,                 0, 1,
            area.x+area.z,  area.y,                 1, 1,
        ];

        glBindBuffer(GL_ARRAY_BUFFER, sceneVBO);
        glBufferData(GL_ARRAY_BUFFER, 24*float.sizeof, data.ptr, GL_DYNAMIC_DRAW);
        renderScene(area, basicSceneShader, fAlbedo, fEmissive, fBump);
    }
    
    override
    bool getPostprocess() {
        return postProcessEnabled; // TODO: implement
    }
    
    override
    void setPostprocess(bool state) {
        postProcessEnabled = state;
    }
    
    override
    void getAmbientLightColor(out float r, out float g, out float b) {
        
    }
    
    override
    void setAmbientLightColor(float r, float g, float b) {
        
    }
    
}

// Internal rendering constants
private {
}

// Things only available internally for Inochi2D rendering
package(inochi2d) {
    
    /**
        Initializes the renderer
    */
    void initRenderer() {
        
    }
}

/**
    Draw scene to area
*/
void inGLDrawScene(vec4 area) {
}

void inGLCompositePrepareRender() {
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, cfAlbedo);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, cfEmissive);
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, cfBump);
}

/**
    Gets the Inochi2D framebuffer 

    DO NOT MODIFY THIS IMAGE!
*/
GLuint inGLGetFramebuffer() {
    return fBuffer;
}

/**
    Gets the Inochi2D framebuffer render image

    DO NOT MODIFY THIS IMAGE!
*/
GLuint inGLGetRenderImage() {
    return fAlbedo;
}

/**
    Gets the Inochi2D composite render image

    DO NOT MODIFY THIS IMAGE!
*/
GLuint inGLGetCompositeImage() {
    return cfAlbedo;
}

/**
    Gets the viewport
*/
void inGLGetViewport(out int width, out int height) nothrow {
}

/**
    Returns length of viewport data for extraction
*/
size_t inGLViewportDataLength() {
    return inViewportWidth * inViewportHeight * 4;
}

/**
    Dumps viewport data to texture stream
*/
void inGLDumpViewport(ref ubyte[] dumpTo) {
    import std.exception : enforce;
    enforce(dumpTo.length >= inViewportDataLength(), "Invalid data destination length for inDumpViewport");
    glBindTexture(GL_TEXTURE_2D, fAlbedo);
    glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE, dumpTo.ptr);

    // We need to flip it because OpenGL renders stuff with a different coordinate system
    ubyte[] tmpLine = new ubyte[inViewportWidth * 4];
    size_t ri = 0;
    foreach_reverse(i; inViewportHeight/2..inViewportHeight) {
        size_t lineSize = inViewportWidth*4;
        size_t oldLineStart = (lineSize*ri);
        size_t newLineStart = (lineSize*i);
        import core.stdc.string : memcpy;

        memcpy(tmpLine.ptr, dumpTo.ptr+oldLineStart, lineSize);
        memcpy(dumpTo.ptr+oldLineStart, dumpTo.ptr+newLineStart, lineSize);
        memcpy(dumpTo.ptr+newLineStart, tmpLine.ptr, lineSize);
        
        ri++;
    }
}

void inRendererInitGL3() {
    GLRenderer renderer = new GLRenderer();
    inRendererInit(renderer);
}