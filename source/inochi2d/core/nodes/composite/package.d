/*
    Inochi2D Composite Node

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.composite;
import inochi2d.core.nodes.common;
import inochi2d.core.nodes;
import inochi2d.fmt;
import inochi2d.core;
import inochi2d.math;
import bindbc.opengl;
import std.exception;
import std.algorithm.sorting;

package(inochi2d) {
    GLuint cVAO;
    GLuint cBuffer;
    Shader cShader;
    Shader cShaderMask;

    GLint gopacity;
    GLint gtint;

    GLint mthreshold;
    GLint mopacity;


    void inInitComposite() {
        inRegisterNodeType!Composite;

        cShader = new Shader(
            import("basic/composite.vert"),
            import("basic/composite.frag")
        );
        gopacity = cShader.getUniformLocation("opacity");
        gtint = cShader.getUniformLocation("tint");

        cShaderMask = new Shader(
            import("basic/composite.vert"),
            import("basic/composite-mask.frag")
        );
        mthreshold = cShader.getUniformLocation("threshold");
        mopacity = cShader.getUniformLocation("opacity");

        glGenVertexArrays(1, &cVAO);
        glGenBuffers(1, &cBuffer);

        // Clip space vertex data since we'll just be superimposing
        // Our composite framebuffer over the main framebuffer
        float[] vertexData = [
            // verts
            -1f, -1f,
            -1f, 1f,
            1f, -1f,
            1f, -1f,
            -1f, 1f,
            1f, 1f,

            // uvs
            0f, 0f,
            0f, 1f,
            1f, 0f,
            1f, 0f,
            0f, 1f,
            1f, 1f,
        ];

        glBindVertexArray(cVAO);
        glBindBuffer(GL_ARRAY_BUFFER, cBuffer);
        glBufferData(GL_ARRAY_BUFFER, float.sizeof*vertexData.length, vertexData.ptr, GL_STATIC_DRAW);
    }
}

/**
    Composite Node
*/
@TypeId("Composite")
class Composite : Node {
private:

    this() { }

    /*
        RENDERING
    */
    void drawSelf() {
        inBeginComposite();

            foreach(Part child; subParts) {
                child.drawOne();
            }

        inEndComposite();

        glBindVertexArray(cVAO);
        cShader.use();
        cShader.setUniform(gopacity, opacity);
        cShader.setUniform(gtint, tint);
        inSetBlendMode(blendingMode);

        // Enable points array
        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(1);
        glBindBuffer(GL_ARRAY_BUFFER, cBuffer);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, cast(void*)(12*float.sizeof));

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, inGetCompositeImage());
        glDrawArrays(GL_TRIANGLES, 0, 6);
    }

    void selfSort() {
        import std.math : cmp;
        sort!((a, b) => cmp(
            a.zSort, 
            b.zSort) > 0)(subParts);
    }

    void scanPartsRecurse(ref Node node) {

        // Don't need to scan null nodes
        if (node is null) return;

        // Do the main check
        if (Part part = cast(Part)node) {
            subParts ~= part;
            foreach(child; part.children) {
                scanPartsRecurse(child);
            }
            
        } else {

            // Non-part nodes just need to be recursed through,
            // they don't draw anything.
            foreach(child; node.children) {
                scanPartsRecurse(child);
            }
        }
    }

protected:
    Part[] subParts;
    
    void renderMask() {
        inBeginComposite();

            // Enable writing to stencil buffer and disable writing to color buffer
            glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
            glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
            glStencilFunc(GL_ALWAYS, 1, 0xFF);
            glStencilMask(0xFF);

            foreach(Part child; subParts) {
                child.drawOneDirect(true);
            }

            // Disable writing to stencil buffer and enable writing to color buffer
            glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
        inEndComposite();


        glBindVertexArray(cVAO);
        cShaderMask.use();
        cShaderMask.setUniform(mopacity, opacity);
        cShaderMask.setUniform(mthreshold, threshold);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

        // Enable points array
        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(1);
        glBindBuffer(GL_ARRAY_BUFFER, cBuffer);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, cast(void*)(12*float.sizeof));

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, inGetCompositeImage());
        glDrawArrays(GL_TRIANGLES, 0, 6);
    }

    override
    void serializeSelf(ref InochiSerializer serializer) {
        super.serializeSelf(serializer);

        serializer.putKey("blend_mode");
        serializer.serializeValue(blendingMode);

        serializer.putKey("tint");
        tint.serialize(serializer);

        serializer.putKey("mask_threshold");
        serializer.putValue(threshold);

        serializer.putKey("opacity");
        serializer.putValue(opacity);
    }

    override
    void serializeSelf(ref InochiSerializerCompact serializer) {
        super.serializeSelf(serializer);

        serializer.putKey("blend_mode");
        serializer.serializeValue(blendingMode);

        serializer.putKey("tint");
        tint.serialize(serializer);

        serializer.putKey("mask_threshold");
        serializer.putValue(threshold);

        serializer.putKey("opacity");
        serializer.putValue(opacity);
    }

    override
    SerdeException deserializeFromFghj(Fghj data) {

        // Older models may not have these tags
        if (!data["opacity"].isEmpty) data["opacity"].deserializeValue(this.opacity);
        if (!data["mask_threshold"].isEmpty) data["mask_threshold"].deserializeValue(this.threshold);
        if (!data["tint"].isEmpty) deserialize(this.tint, data["tint"]);
        if (!data["blend_mode"].isEmpty) data["blend_mode"].deserializeValue(this.blendingMode);
        
        return super.deserializeFromFghj(data);
    }


    override
    string typeId() { return "Composite"; }

public:

    /**
        The blending mode
    */
    BlendMode blendingMode;

    /**
        The opacity of the composite
    */
    float opacity = 1;

    /**
        The threshold for rendering masks
    */
    float threshold = 0.5;

    /**
        The tint of the composite
    */
    vec3 tint = vec3(1, 1, 1);


    /**
        Constructs a new mask
    */
    this(Node parent = null) {
        this(inCreateUUID(), parent);
    }

    /**
        Constructs a new composite
    */
    this(uint uuid, Node parent = null) {
        super(uuid, parent);
    }

    override
    void drawOne() {
        super.drawOne();

        this.selfSort();
        this.drawSelf();
    }

    override
    void beginUpdate() {
        this.selfSort();
        super.beginUpdate();
    }

    override
    void draw() {
        if (!enabled) return;
        this.drawOne();
    }

    /**
        Scans for parts to render
    */
    void scanParts() {
        subParts.length = 0;
        if (children.length > 0) {
            scanPartsRecurse(children[0].parent);
        }
    }
}