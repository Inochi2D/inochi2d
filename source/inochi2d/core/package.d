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
import inochi2d.core.dbg;

import bindbc.opengl;
import inochi2d.math;
import std.stdio;

// Internal rendering constants
private {
    // Viewport
    int inViewportWidth;
    int inViewportHeight;

    Shader sceneShader;
    GLuint sceneVAO;
    GLuint sceneVBO;
    GLint sceneMVP;

    GLuint fBuffer;
    GLuint fColor;
    GLuint fStencil;


    Shader[] blendingShaders;

    // Camera
    Camera inCamera;
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
        inInitNodes();
        inInitPathDeform();
        inInitDrawable();
        inInitPart();
        inInitMask();
        inInitDebug();

        // Some defaults that should be changed by app writer
        inCamera = new Camera;

        // Shader for scene
        sceneShader = new Shader(import("scene.vert"), import("scene.frag"));
        sceneMVP = sceneShader.getUniformLocation("mvp");
        glGenVertexArrays(1, &sceneVAO);
        glGenBuffers(1, &sceneVBO);

        // Generate the framebuffer we'll be using to render the model
        glGenFramebuffers(1, &fBuffer);
        
        // Generate the color and stencil-depth textures needed
        // Note: we're not using the depth buffer but OpenGL 3.4 does not support stencil-only buffers
        glGenTextures(1, &fColor);
        glGenTextures(1, &fStencil);

        // Attach textures to framebuffer
        glBindFramebuffer(GL_FRAMEBUFFER, fBuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, fColor, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, fStencil, 0);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
}

/**
    Begins rendering to the framebuffer
*/
void inBeginScene() { 
    glEnable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);

    // Make sure to reset our viewport if someone has messed with it
    glViewport(0, 0, inViewportWidth, inViewportHeight);

    // Bind our framebuffer
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fBuffer);
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);

    // Everything else is the actual texture used by the meshes at id 0
    glActiveTexture(GL_TEXTURE0);

    glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);
}

/**
    Ends rendering to the framebuffer
*/
void inEndScene() {
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    glDisable(GL_BLEND);
    glEnable(GL_DEPTH_TEST);
    glFlush();
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
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, cast(int)area.z, cast(int)area.w);

    // Bind our vertex array
    glBindVertexArray(sceneVAO);
    
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);

    sceneShader.use();
    sceneShader.setUniform(sceneMVP, 
        mat4.orthographic(0, area.z, area.w, 0, 0, max(area.z, area.w)) * 
        mat4.translation(area.x, area.y, 0)
    );

    // Bind the texture
    glBindTexture(GL_TEXTURE_2D, fColor);
    glActiveTexture(GL_TEXTURE0);

    // Enable points array
    glEnableVertexAttribArray(0); // verts
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

/**
    Gets the Inochi2D framebuffer render image

    DO NOT MODIFY THIS IMAGE!
*/
GLuint inGetRenderImage() {
    return fColor;
}

/**
    Sets the viewport area to render to
*/
void inSetViewport(int width, int height) nothrow {

    inViewportWidth = width;
    inViewportHeight = height;

    glBindTexture(GL_TEXTURE_2D, fColor);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glBindTexture(GL_TEXTURE_2D, fStencil);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH24_STENCIL8, width, height, 0, GL_DEPTH_STENCIL, GL_UNSIGNED_INT_24_8, null);

    glBindFramebuffer(GL_FRAMEBUFFER, fBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, fColor, 0);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, fStencil, 0);
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
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
    glBindTexture(GL_TEXTURE_2D, fColor);
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