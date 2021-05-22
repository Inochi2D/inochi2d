/*
    Inochi2D Part

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.part;
import inochi2d.core.nodes.drawable;
import inochi2d.core;
import inochi2d.math;
import bindbc.opengl;
import std.exception;
import std.algorithm.mutation : copy;

public import inochi2d.core.meshdata;


package(inochi2d) {
    private {
        Shader partShader;
        Shader partMaskShader;
    }

    void inInitPart() {
        partShader = new Shader(import("basic/basic.vert"), import("basic/basic.frag"));
        partMaskShader = new Shader(import("basic/basic.vert"), import("basic/basic-mask.frag"));
    }
}

/**
    Masking mode
*/
enum MaskingMode {

    /**
        The part should be masked by the drawables specified
    */
    Mask,

    /**
        The path should be dodge masked by the drawables specified
    */
    DodgeMask
}

/**
    Dynamic Mesh Part
*/
class Part : Drawable {
private:
    
    /* current texture */
    size_t currentTexture = 0;
    
    GLuint uvbo;

    /* GLSL Uniforms (Normal) */
    GLint mvp;
    GLint gopacity;

    /* GLSL Uniforms (Masks) */
    GLint mmvp;
    GLint mthreshold;
    GLint mgopacity;

    void updateUVs() {
        glBindBuffer(GL_ARRAY_BUFFER, uvbo);
        glBufferData(GL_ARRAY_BUFFER, data.uvs.length*vec2.sizeof, data.uvs.ptr, GL_STATIC_DRAW);
    }

    /*
        RENDERING
    */

    void drawSelf(bool isMask = false)() {

        // Bind the vertex array
        this.bindVertexArray();

        static if (isMask) {
            partMaskShader.use();
            partMaskShader.setUniform(mmvp, inGetCamera().matrix * transform.matrix());
            partMaskShader.setUniform(mthreshold, maskAlphaThreshold);
            partMaskShader.setUniform(mgopacity, opacity);
        } else {
            partShader.use();
            partShader.setUniform(mvp, inGetCamera().matrix * transform.matrix());
            partShader.setUniform(gopacity, opacity);
        }

        // Bind the texture
        textures[currentTexture].bind();

        // Enable points array
        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Enable UVs array
        glEnableVertexAttribArray(1); // uvs
        glBindBuffer(GL_ARRAY_BUFFER, uvbo);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Bind index buffer
        this.bindIndex();

        // Disable the vertex attribs after use
        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
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
        drawSelf!true();

        // Disable writing to stencil buffer and enable writing to color buffer
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    }

public:
    /**
        List of textures this part can use
    */
    Texture[] textures;

    /**
        A part this part should "dodge"
    */
    Drawable[] mask;

    /**
        Masking mode
    */
    MaskingMode maskingMode = MaskingMode.Mask;
    
    /**
        Alpha Threshold for the masking system, the higher the more opaque pixels will be discarded in the masking process
    */
    float maskAlphaThreshold = 0.01;

    /**
        Opacity of the mesh
    */
    float opacity = 1;

    /**
        Gets the active texture
    */
    Texture activeTexture() {
        return textures[currentTexture];
    }

    /**
        Constructs a new part
    */
    this(MeshData data, Texture[] textures, Node parent = null) {
        this(data, textures, inCreateUUID(), parent);
    }

    /**
        Constructs a new part
    */
    this(MeshData data, Texture[] textures, uint uuid, Node parent = null) {
        super(data, uuid, parent);
        this.textures = textures;
        glGenBuffers(1, &uvbo);

        mvp = partShader.getUniformLocation("mvp");
        gopacity = partShader.getUniformLocation("opacity");
        
        mmvp = partMaskShader.getUniformLocation("mvp");
        mthreshold = partMaskShader.getUniformLocation("threshold");
        mgopacity = partMaskShader.getUniformLocation("opacity");
        this.updateUVs();
    }

    override
    void rebuffer(MeshData data) {
        super.rebuffer(data);
        this.updateUVs();
    }

    override
    void drawOne() {
        if (!enabled) return;
        
        glUniform1f(mthreshold, maskAlphaThreshold);
        glUniform1f(mgopacity, opacity);
        
        if (mask.length > 0) {
            inBeginMask();

            foreach(drawable; mask) {
                drawable.renderMask();
            }

            // Begin drawing content
            if (maskingMode == MaskingMode.Mask) inBeginMaskContent();
            else inBeginDodgeContent();
            
            // We are the content
            this.drawSelf();

            inEndMask();
            return;
        }

        this.drawSelf();
    }

    override
    void draw() {
        if (!enabled) return;
        this.drawOne();

        foreach(child; children) {
            child.draw();
        }
    }

}