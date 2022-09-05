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

private {
    GLuint cVAO;
    GLuint cBuffer;
    Shader cShader;
    Shader cShaderMask;

    GLint gopacity;
    GLint gMultColor;
    GLint gScreenColor;

    GLint mthreshold;
    GLint mopacity;
}

package(inochi2d) {
    void inInitComposite() {
        inRegisterNodeType!Composite;

        version(InDoesRender) {
            cShader = new Shader(
                import("basic/composite.vert"),
                import("basic/composite.frag")
            );

            cShader.use();
            gopacity = cShader.getUniformLocation("opacity");
            gMultColor = cShader.getUniformLocation("multColor");
            gScreenColor = cShader.getUniformLocation("screenColor");
            cShader.setUniform(cShader.getUniformLocation("albedo"), 0);
            cShader.setUniform(cShader.getUniformLocation("emissive"), 1);
            cShader.setUniform(cShader.getUniformLocation("bumpmap"), 2);

            cShaderMask = new Shader(
                import("basic/composite.vert"),
                import("basic/composite-mask.frag")
            );
            cShaderMask.use();
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

        // Optimization: Nothing to be drawn, skip context switching
        if (subParts.length == 0) return;

        inBeginComposite();

            foreach(Part child; subParts) {
                child.drawOne();
            }

        inEndComposite();

        glBindVertexArray(cVAO);

        cShader.use();
        cShader.setUniform(gopacity, clamp(offsetOpacity * opacity, 0, 1));
        incCompositePrepareRender();
        
        vec3 clampedColor = tint;
        if (!offsetTint.x.isNaN) clampedColor.x = clamp(tint.x*offsetTint.x, 0, 1);
        if (!offsetTint.y.isNaN) clampedColor.y = clamp(tint.y*offsetTint.y, 0, 1);
        if (!offsetTint.z.isNaN) clampedColor.z = clamp(tint.z*offsetTint.z, 0, 1);
        cShader.setUniform(gMultColor, clampedColor);

        clampedColor = screenTint;
        if (!offsetScreenTint.x.isNaN) clampedColor.x = clamp(screenTint.x+offsetScreenTint.x, 0, 1);
        if (!offsetScreenTint.y.isNaN) clampedColor.y = clamp(screenTint.y+offsetScreenTint.y, 0, 1);
        if (!offsetScreenTint.z.isNaN) clampedColor.z = clamp(screenTint.z+offsetScreenTint.z, 0, 1);
        cShader.setUniform(gScreenColor, clampedColor);
        inSetBlendMode(blendingMode);

        // Enable points array
        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(1);
        glBindBuffer(GL_ARRAY_BUFFER, cBuffer);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, cast(void*)(12*float.sizeof));

        // Bind the texture
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

        serializer.putKey("screenTint");
        screenTint.serialize(serializer);

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
        if (!data["screenTint"].isEmpty) deserialize(this.screenTint, data["screenTint"]);
        if (!data["blend_mode"].isEmpty) data["blend_mode"].deserializeValue(this.blendingMode);
        
        return super.deserializeFromFghj(data);
    }

    //
    //      PARAMETER OFFSETS
    //
    float offsetOpacity = 1;
    vec3 offsetTint = vec3(0);
    vec3 offsetScreenTint = vec3(0);

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
        Multiplicative tint color
    */
    vec3 tint = vec3(1, 1, 1);

    /**
        Screen tint color
    */
    vec3 screenTint = vec3(0, 0, 0);


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
    bool hasParam(string key) {
        if (super.hasParam(key)) return true;

        switch(key) {
            case "opacity":
            case "tint.r":
            case "tint.g":
            case "tint.b":
            case "screenTint.r":
            case "screenTint.g":
            case "screenTint.b":
                return true;
            default:
                return false;
        }
    }

    override
    float getDefaultValue(string key) {
        // Skip our list of our parent already handled it
        float def = super.getDefaultValue(key);
        if (!isNaN(def)) return def;

        switch(key) {
            case "opacity":
            case "tint.r":
            case "tint.g":
            case "tint.b":
                return 1;
            case "screenTint.r":
            case "screenTint.g":
            case "screenTint.b":
                return 0;
            default: return float();
        }
    }

    override
    bool setValue(string key, float value) {
        
        // Skip our list of our parent already handled it
        if (super.setValue(key, value)) return true;

        switch(key) {
            case "opacity":
                offsetOpacity = value;
                return true;
            case "tint.r":
                offsetTint.x = value;
                return true;
            case "tint.g":
                offsetTint.y = value;
                return true;
            case "tint.b":
                offsetTint.z = value;
                return true;
            case "screenTint.r":
                offsetScreenTint.x = value;
                return true;
            case "screenTint.g":
                offsetScreenTint.y = value;
                return true;
            case "screenTint.b":
                offsetScreenTint.z = value;
                return true;
            default: return false;
        }
    }

    override
    void beginUpdate() {
        offsetOpacity = 1;
        offsetTint = vec3(1, 1, 1);
        super.beginUpdate();
    }

    override
    void drawOne() {
        super.drawOne();

        this.selfSort();
        this.drawSelf();
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