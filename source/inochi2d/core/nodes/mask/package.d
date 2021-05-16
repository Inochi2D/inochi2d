/*
    Inochi2D Mask

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.mask;
import inochi2d.core.nodes.drawable;
import inochi2d.core;
import inochi2d.math;
import bindbc.opengl;
import std.exception;
import std.algorithm.mutation : copy;

public import inochi2d.core.meshdata;


package(inochi2d) {
    private {
        Shader maskShader;
    }

    void inInitMask() {
        maskShader = new Shader(import("mask.vert"), import("mask.frag"));
    }
}

/**
    Dynamic Mask Part
*/
class Mask : Drawable {
private:

    /* GLSL Uniforms (Normal) */
    GLint mvp;

    /*
        RENDERING
    */
    void drawSelf() {

        // Bind the vertex array
        this.bindVertexArray();

        maskShader.use();
        maskShader.setUniform(mvp, inGetCamera().matrix * transform.matrix());
        
        // Enable points array
        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Bind index buffer
        this.bindIndex();

        // Disable the vertex attribs after use
        glDisableVertexAttribArray(0);
    }

protected:
    override
    void renderMask() {
        
        // Enable writing to stencil buffer and disable writing to color buffer
        glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
        glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
        glStencilFunc(GL_ALWAYS, 1, 0xFF);
        glStencilMask(0xFF);

        // Draw ourselves to the stencil buffer
        drawSelf();

        // Disable writing to stencil buffer and enable writing to color buffer
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    }

public:

    /**
        Constructs a new mask
    */
    this(MeshData data, Node parent = null) {
        super(data, parent);
        mvp = maskShader.getUniformLocation("mvp");
    }

    override
    void rebuffer(MeshData data) {
        super.rebuffer(data);
    }

    override
    void drawOne() {

    }

    override
    void draw() {
        if (!enabled) return;
        foreach(child; children) {
            child.draw();
        }
    }

}