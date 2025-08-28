/*
    Inochi2D Rendering

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core;

public import inochi2d.core.shader;
public import inochi2d.core.texture;
public import inochi2d.core.nodes;
public import inochi2d.core.puppet;
public import inochi2d.core.meshdata;
public import inochi2d.core.param;
public import inochi2d.core.automation;
public import inochi2d.core.animation;
import inochi2d.fmt.serde;
import inochi2d.core.dbg;

import bindbc.opengl;
import inochi2d.core.math;
import std.stdio;

version(Windows) {
    // Ask Windows nicely to use dedicated GPUs :)
    export extern(C) int NvOptimusEnablement = 0x00000001;
    export extern(C) int AmdPowerXpressRequestHighPerformance = 0x00000001;
}

struct PostProcessingShader {
private:
    GLint[string] uniformCache;

public:
    Shader shader;
    this(Shader shader) {
        this.shader = shader;

        shader.use();
        shader.compile();
        shader.setUniform(shader.getUniformLocation("albedo"), 0);
        shader.setUniform(shader.getUniformLocation("emissive"), 1);
        shader.setUniform(shader.getUniformLocation("bumpmap"), 2);
    }

    /**
        Gets the location of the specified uniform
    */
    GLuint getUniform(string name) {
        if (this.hasUniform(name)) return uniformCache[name];
        GLint element = shader.getUniformLocation(name);
        uniformCache[name] = element;
        return element;
    }

    /**
        Returns true if the uniform is present in the shader cache 
    */
    bool hasUniform(string name) {
        return (name in uniformCache) !is null;
    }
}

// Internal rendering constants
private {
    // Viewport
    int inViewportWidth;
    int inViewportHeight;

    GLuint sceneVAO;
    GLuint sceneVBO;

    GLuint fBuffer;
    GLuint fAlbedo;
    GLuint fEmissive;
    GLuint fBump;
    GLuint fStencil;

    GLuint cfBuffer;
    GLuint cfAlbedo;
    GLuint cfEmissive;
    GLuint cfBump;
    GLuint cfStencil;

    GLint lastFBO;

    vec4 inClearColor;

    PostProcessingShader basicSceneShader;
    PostProcessingShader basicSceneLighting;
    PostProcessingShader[] postProcessingStack;

    // Camera
    Camera inCamera;

    bool isCompositing;

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
        shaderToUse.shader.setUniform(shaderToUse.getUniform("mvpModel"), 
            mat4.identity()
        );
        shaderToUse.shader.setUniform(shaderToUse.getUniform("mvpView"), 
            mat4.translation(area.x, area.y, 0)
        );
        shaderToUse.shader.setUniform(shaderToUse.getUniform("mvpProjection"), 
            mat4.orthographic(0, area.z, area.w, 0, 0, max(area.z, area.w))
        );

        // Ambient light
        GLint ambientLightUniform = shaderToUse.getUniform("ambientLight");
        if (ambientLightUniform != -1) shaderToUse.shader.setUniform(ambientLightUniform, inSceneAmbientLight);

        // Light direction
        GLint lightDirUniform = shaderToUse.getUniform("inLightDir");
        if (lightDirUniform != -1) shaderToUse.shader.setUniform(lightDirUniform, inSceneLightDir);

        // Colored light
        GLint lightColorUniform = shaderToUse.getUniform("lightColor");
        if (lightColorUniform != -1) shaderToUse.shader.setUniform(lightColorUniform, inSceneLightColor);

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
}

// Things only available internally for Inochi2D rendering
package(inochi2d) {
    
    /**
        Initializes the renderer
    */
    void initRenderer() {

        // Set the viewport and by extension set the textures
        inSetViewport(640, 480);
        
        // Initialize dynamic meshes
        inInitBlending();
        inInitNodes();
        inInitDrawable();
        inInitPart();
        inInitComposite();
        inInitMeshGroup();
        inInitDebug();

        inParameterSetFactory((ref JSONValue data) {
            Parameter param = new Parameter;
            data.deserialize(param);
            return param;
        });

        // Some defaults that should be changed by app writer
        inCamera = new Camera;

        inClearColor = vec4(0, 0, 0, 0);

        // Shader for scene
        basicSceneShader = PostProcessingShader(new Shader("scene", import("scene.vert"), import("scene.frag")));
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

        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &lastFBO);

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
        glBindFramebuffer(GL_FRAMEBUFFER, lastFBO);
    }
}

/// Ambient light value
vec3 inSceneAmbientLight = vec3(0.1, 0.1, 0.2);

/// Color of the light shining into the scene
vec3 inSceneLightColor = vec3(0.65, 0.54, 0.54);

/// Unit vector describing the direction of the light
vec3 inSceneLightDir = vec3(0, 0, 1);

/// Use depth-buffer for masking.
bool inDepthBufferMasks = true;

/**
    Begins rendering to the framebuffer
*/
void inBeginScene() {
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &lastFBO);

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

/**
    Begins a composition step
*/
void inBeginComposite() {

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

/**
    Ends a composition step, re-binding the internal framebuffer
*/
void inEndComposite() {

    // We don't allow recursive compositing
    if (!isCompositing) return;
    isCompositing = false;

    glBindFramebuffer(GL_FRAMEBUFFER, fBuffer);
    glDrawBuffers(3, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);
    glFlush();
}

/**
    Ends rendering to the framebuffer
*/
void inEndScene() {
    glBindFramebuffer(GL_FRAMEBUFFER, lastFBO);

    glDisablei(GL_BLEND, 0);
    glDisablei(GL_BLEND, 1);
    glDisablei(GL_BLEND, 2);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glDisable(GL_BLEND);
    glFlush();
    glDrawBuffers(1, [GL_COLOR_ATTACHMENT0].ptr);
}

/**
    Runs post processing on the scene
*/
void inPostProcessScene() {
    if (postProcessingStack.length == 0) return;
    
    bool targetBuffer;

    // These are passed to glSetClearColor for transparent export
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
    glClearColor(r, g, b, a);
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
    
    glBindFramebuffer(GL_FRAMEBUFFER, lastFBO);
}

/**
    Add basic lighting shader to processing stack
*/
void inPostProcessingAddBasicLighting() {
    postProcessingStack ~= PostProcessingShader(
        new Shader("scene+lighting", 
            import("scene.vert"),
            import("lighting.frag")
        )
    );
}

/**
    Clears the post processing stack
*/
ref PostProcessingShader[] inGetPostProcessingStack() {
    return postProcessingStack;
}

/**
    Gets the global camera
*/
Camera inGetCamera() {
    return inCamera;
}

/**
    Sets the global camera, allows switching between cameras
*/
void inSetCamera(Camera camera) {
    inCamera = camera;
}

/**
    Draw scene to area
*/
void inDrawScene(vec4 area) {
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

void incCompositePrepareRender() {
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
GLuint inGetFramebuffer() {
    return fBuffer;
}

/**
    Gets the Inochi2D framebuffer render image

    DO NOT MODIFY THIS IMAGE!
*/
GLuint inGetRenderImage() {
    return fAlbedo;
}

/**
    Gets the Inochi2D composite render image

    DO NOT MODIFY THIS IMAGE!
*/
GLuint inGetCompositeImage() {
    return cfAlbedo;
}

/**
    Sets the viewport area to render to
*/
void inSetViewport(int width, int height) nothrow {

    // Skip resizing when not needed.
    if (width == inViewportWidth && height == inViewportHeight) return;

    inViewportWidth = width;
    inViewportHeight = height;

    // Render Framebuffer
    glBindTexture(GL_TEXTURE_2D, fAlbedo);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glBindTexture(GL_TEXTURE_2D, fEmissive);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_FLOAT, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glBindTexture(GL_TEXTURE_2D, fBump);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glBindTexture(GL_TEXTURE_2D, fStencil);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH24_STENCIL8, width, height, 0, GL_DEPTH_STENCIL, GL_UNSIGNED_INT_24_8, null);

    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &lastFBO);
        glBindFramebuffer(GL_FRAMEBUFFER, fBuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, fAlbedo, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, fEmissive, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, fBump, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, fStencil, 0);
        

        // Composite framebuffer
        glBindTexture(GL_TEXTURE_2D, cfAlbedo);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        
        glBindTexture(GL_TEXTURE_2D, cfEmissive);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_FLOAT, null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        
        glBindTexture(GL_TEXTURE_2D, cfBump);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        
        glBindTexture(GL_TEXTURE_2D, cfStencil);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH24_STENCIL8, width, height, 0, GL_DEPTH_STENCIL, GL_UNSIGNED_INT_24_8, null);

        glBindFramebuffer(GL_FRAMEBUFFER, cfBuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, cfAlbedo, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, cfEmissive, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, cfBump, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, cfStencil, 0);

    glBindFramebuffer(GL_FRAMEBUFFER, lastFBO);
    glViewport(0, 0, width, height);
    
}

/**
    Gets the viewport
*/
void inGetViewport(out int width, out int height) nothrow {
    width = inViewportWidth;
    height = inViewportHeight;
}

/**
    Returns length of viewport data for extraction
*/
size_t inViewportDataLength() {
    return inViewportWidth * inViewportHeight * 4;
}

/**
    Dumps viewport data to texture stream
*/
void inDumpViewport(ref ubyte[] dumpTo) {
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

/**
    Sets the background clear color
*/
void inSetClearColor(float r, float g, float b, float a) {
    inClearColor = vec4(r, g, b, a);
}

/**

*/
void inGetClearColor(out float r, out float g, out float b, out float a) {
    r = inClearColor.r;
    g = inClearColor.g;
    b = inClearColor.b;
    a = inClearColor.a;
}

/**
    UDA for sub-classable parts of the spec
    eg. Nodes and Automation can be extended by
    adding new subclasses that aren't in the base spec.
*/
struct TypeId { string id; }

/**
    Different modes of interpolation between values.
*/
enum InterpolateMode {

    /**
        Round to nearest
    */
    Nearest,
    
    /**
        Linear interpolation
    */
    Linear,

    /**
        Round to nearest
    */
    Stepped,

    /**
        Cubic interpolation
    */
    Cubic,

    /**
        Interpolation using beziér splines
    */
    Bezier,

    COUNT
}
