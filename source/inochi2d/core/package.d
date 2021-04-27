/*
    Inochi2D Rendering

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core;

public import inochi2d.core.shader;
public import inochi2d.core.texture;
public import inochi2d.core.node;

import bindbc.opengl;
import inochi2d.math;

enum BlendingMode : size_t {
    /**
        Normal blending
    */
    Normal      = 0,

    /**
        Multiply/Shadow blending
    */
    Multiply    = 1,

    /**
        Screen blending
    */
    Screen      = 2,

    /**
        Reflection blending
    */
    Reflect     = 3,

    /**
        Glow blending
    */
    Glow        = 4,

    /**
        Overlay blending
    */
    Overlay     = 5,

    /**
        Darken blending
    */
    Darken      = 6,

    /**
        Amount of blending modes available
    */
    ModeCount
}

// Internal rendering constants
private {
    // Viewport
    int inViewportWidth;
    int inViewportHeight;

    Shader sceneShader;
    GLuint sceneVAO;
    GLuint sceneVBO;
    GLint sceneMVP;

    GLuint fColor;
    GLuint fStencil;
    GLuint framebuffer;

    Shader[] blendingShaders;

    // Camera
    Camera inCamera;

    // Updates the FBO to fit the viewport
    void updateFBO() {

        // Color texture
        glBindTexture(GL_TEXTURE_2D, fColor);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, inViewportWidth, inViewportHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);

        // Stencil texture
        glBindTexture(GL_TEXTURE_2D, fStencil);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH24_STENCIL8, inViewportWidth, inViewportHeight, 0, GL_DEPTH_STENCIL, GL_UNSIGNED_INT_24_8, null);

    }
}

// Things only available internally for Inochi2D rendering
package(inochi2d) {
    
    /**
        Initializes the renderer
    */
    void initRenderer() {
        
        // Initialize dynamic meshes
        inInitPart();

        // Some defaults that should be changed by app writer
        inCamera = new Camera;

        // Shader for scene
        sceneShader = new Shader(import("scene.vert"), import("scene.frag"));
        sceneMVP = sceneShader.getUniformLocation("mvp");
        glGenVertexArrays(1, &sceneVAO);
        glGenBuffers(1, &sceneVBO);

        // Generate the framebuffer we'll be using to render the model
        glGenFramebuffers(1, &framebuffer);
        
        // Generate the color and stencil-depth textures needed
        // Note: we're not using the depth buffer but OpenGL 3.4 does not support stencil-only buffers
        glGenTextures(1, &fColor);
        glGenTextures(1, &fStencil);

        // Set the viewport and by extension set the textures
        inSetViewport(640, 480);

        // Attach textures to framebuffer
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, fColor, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, fStencil, 0);

        // TODO: load the shader code for puppet vertex only once?
        string puppetVert = import("blending/puppet.vert");

        // Set length to count of blending modes
        blendingShaders.length = cast(size_t)BlendingMode.ModeCount;

        // Init all the blending modes
        blendingShaders[0] = new Shader(puppetVert, import("blending/normal.frag")); // Normal blending
        blendingShaders[0].use();
        glUniform1i(blendingShaders[0].getUniformLocation("tex"), 0);
        glUniform1i(blendingShaders[0].getUniformLocation("screen"), 1);
        
        blendingShaders[1] = new Shader(puppetVert, import("blending/multiply.frag")); // Multiply blending
        blendingShaders[1].use();
        glUniform1i(blendingShaders[1].getUniformLocation("tex"), 0);
        glUniform1i(blendingShaders[1].getUniformLocation("screen"), 1);
        
        blendingShaders[2] = new Shader(puppetVert, import("blending/screen.frag")); // Screen blending
        blendingShaders[2].use();
        glUniform1i(blendingShaders[2].getUniformLocation("tex"), 0);
        glUniform1i(blendingShaders[2].getUniformLocation("screen"), 1);
        
        blendingShaders[3] = new Shader(puppetVert, import("blending/reflect.frag")); // Reflect blending
        blendingShaders[3].use();
        glUniform1i(blendingShaders[3].getUniformLocation("tex"), 0);
        glUniform1i(blendingShaders[3].getUniformLocation("screen"), 1);
        
        blendingShaders[4] = new Shader(puppetVert, import("blending/glow.frag")); // Glow blending
        blendingShaders[4].use();
        glUniform1i(blendingShaders[4].getUniformLocation("tex"), 0);
        glUniform1i(blendingShaders[4].getUniformLocation("screen"), 1);
        
        blendingShaders[5] = new Shader(puppetVert, import("blending/overlay.frag")); // Overlay blending
        blendingShaders[5].use();
        glUniform1i(blendingShaders[5].getUniformLocation("tex"), 0);
        glUniform1i(blendingShaders[5].getUniformLocation("screen"), 1);
        
        blendingShaders[6] = new Shader(puppetVert, import("blending/darken.frag")); // Darken blending
        blendingShaders[6].use();
        glUniform1i(blendingShaders[6].getUniformLocation("tex"), 0);
        glUniform1i(blendingShaders[6].getUniformLocation("screen"), 1);
    }

    Shader inGetBlend(BlendingMode mode) {
        return blendingShaders[mode];
    }

    /**
        Specify which blending mode to use
    */
    void inBlend(BlendingMode mode) {
        blendingShaders[mode].use();
    }
}

/**
    Begins rendering to the framebuffer
*/
void inBeginScene() {
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);

    // Set color to texture 1
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, fColor);

    // Everything else is the actual texture used by the meshes at id 0
    glActiveTexture(GL_TEXTURE0);
}

/**
    Ends rendering to the framebuffer
*/
void inEndScene() {
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
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
    glBindVertexArray(sceneVAO);
    
    glDisable(GL_CULL_FACE);

    sceneShader.use();
    sceneShader.setUniform(sceneMVP, mat4.orthographic(-2f, area.z, area.w, 0, 0, max(area.z, area.w)) * mat4.translation(area.x, area.y, 0));

    // Bind our vertex array
    glBindVertexArray(sceneVAO);

    // Bind the texture
    glBindTexture(GL_TEXTURE_2D, fColor);

    // Enable points array
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, sceneVBO);
    float[] data = [
        area.x,         area.y,         0, 0,
        area.x,         area.y+area.w,  0, 1,
        area.x+area.z,  area.y,         1, 0,
        
        area.x+area.z,  area.y,         1, 0,
        area.x,         area.y+area.w,  0, 1,
        area.x+area.z,  area.y+area.w,  1, 1,
    ];
    glBufferData(GL_ARRAY_BUFFER, 24*float.sizeof, data.ptr, GL_DYNAMIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4*float.sizeof, null);

    // Enable UVs array
    glEnableVertexAttribArray(1); // uvs
    glBindBuffer(GL_ARRAY_BUFFER, sceneVBO);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4*float.sizeof, cast(float*)(2*float.sizeof));

    // Draw
    glDrawArrays(GL_TRIANGLES, 0, 6);

    // Disable the vertex attribs after use
    glDisableVertexAttribArray(0);
    glDisableVertexAttribArray(1);
}

/**
    Sets the viewport area to render to
*/
void inSetViewport(int width, int height) {
    // We bind our framebuffer so we can resize the viewport inside of it
    inBeginScene();

    inViewportWidth = width;
    inViewportHeight = height;

    // Update FBO
    updateFBO();

    // Then update the viewport
    glViewport(0, 0, width, height);

    // We want to make sure we don't mess up other program state.
    inEndScene();
}

/**
    Gets the viewport
*/
void inGetViewport(out int width, out int height) {
    width = inViewportWidth;
    height = inViewportHeight;
}