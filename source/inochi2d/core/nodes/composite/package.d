/*
    Inochi2D Composite Node

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.composite;
import inochi2d.core.nodes.drawable;
import inochi2d.core.nodes.common;
import inochi2d.core.nodes;
import inochi2d.fmt;
import inochi2d.core;
import inochi2d.core.math;
import bindbc.opengl;
import std.exception;
import std.algorithm.sorting;

private {
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

        cShader = new Shader("composite",
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

        cShaderMask = new Shader("composite (mask)",
            import("basic/composite.vert"),
            import("basic/composite-mask.frag")
        );

        cShaderMask.use();
        mthreshold = cShader.getUniformLocation("threshold");
        mopacity = cShader.getUniformLocation("opacity");
    }
}

/**
    Composite Node
*/
@TypeId("Composite")
class Composite : Node {
private:

    this() { }

    void drawContents() {

        // Optimization: Nothing to be drawn, skip context switching
        if (subParts.length == 0) return;

        inBeginComposite();

            foreach(Part child; subParts) {
                child.drawOne();
            }

        inEndComposite();
    }

    /*
        RENDERING
    */
    void drawSelf() {
        if (subParts.length == 0) return;

        glDrawBuffers(3, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);

        cShader.use();
        cShader.setUniform(gopacity, clamp(offsetOpacity * opacity, 0, 1));
        incCompositePrepareRender();
        
        vec3 clampedColor = tint;
        if (offsetTint.isFinite) {
            clampedColor.x = clamp(tint.x*offsetTint.x, 0, 1);
            clampedColor.y = clamp(tint.y*offsetTint.y, 0, 1);
            clampedColor.z = clamp(tint.z*offsetTint.z, 0, 1);
        } 
        cShader.setUniform(gMultColor, clampedColor);

        clampedColor = screenTint;
        if (offsetScreenTint.isFinite) {
            clampedColor.x = clamp(screenTint.x+offsetScreenTint.x, 0, 1);
            clampedColor.y = clamp(screenTint.y+offsetScreenTint.y, 0, 1);
            clampedColor.z = clamp(screenTint.z+offsetScreenTint.z, 0, 1);
        } 
        cShader.setUniform(gScreenColor, clampedColor);
        inSetBlendMode(blendingMode, true);

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

        cShaderMask.use();
        cShaderMask.setUniform(mopacity, opacity);
        cShaderMask.setUniform(mthreshold, threshold);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, inGetCompositeImage());
        glDrawArrays(GL_TRIANGLES, 0, 6);
    }

    override
    void serializeSelfImpl(ref JSONValue object, bool recursive=true) {
        super.serializeSelfImpl(object, recursive);
        object["blend_mode"] = blendingMode;
        object["tint"] = tint.serialize();
        object["screenTint"] = screenTint.serialize();
        object["mask_threshold"] = threshold;
        object["opacity"] = opacity;
        object["propagate_meshgroup"] = propagateMeshGroup;
        object["masks"] = masks.serialize();
    }

    override
    void onDeserialize(ref JSONValue object) {
        object.tryGetRef(opacity, "opacity");
        object.tryGetRef(threshold, "mask_threshold");
        object.tryGetRef(tint, "tint");
        object.tryGetRef(screenTint, "screenTint");
        object.tryGetRef(masks, "masks");
        object.tryGetRef(propagateMeshGroup, "propagate_meshgroup", false);
        blendingMode = object.tryGet!string("blend_mode", "Normal").toBlendMode();
        
        super.onDeserialize(object);
    }

    //
    //      PARAMETER OFFSETS
    //
    float offsetOpacity = 1;
    vec3 offsetTint = vec3(0);
    vec3 offsetScreenTint = vec3(0);

    override
    string typeId() { return "Composite"; }

    // TODO: Cache this
    size_t maskCount() {
        size_t c;
        foreach(m; masks) if (m.mode == MaskingMode.Mask) c++;
        return c;
    }

    size_t dodgeCount() {
        size_t c;
        foreach(m; masks) if (m.mode == MaskingMode.DodgeMask) c++;
        return c;
    }

    override
    void preProcess() {
        if (!propagateMeshGroup)
            Node.preProcess();
    }

    override
    void postProcess() {
        if (!propagateMeshGroup)
            Node.postProcess();
    }

public:
    bool propagateMeshGroup = true;

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
        List of masks to apply
    */
    MaskBinding[] masks;


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
        if (def.isFinite) return def;

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
                offsetOpacity *= value;
                return true;
            case "tint.r":
                offsetTint.x *= value;
                return true;
            case "tint.g":
                offsetTint.y *= value;
                return true;
            case "tint.b":
                offsetTint.z *= value;
                return true;
            case "screenTint.r":
                offsetScreenTint.x += value;
                return true;
            case "screenTint.g":
                offsetScreenTint.y += value;
                return true;
            case "screenTint.b":
                offsetScreenTint.z += value;
                return true;
            default: return false;
        }
    }
    
    override
    float getValue(string key) {
        switch(key) {
            case "opacity":         return offsetOpacity;
            case "tint.r":          return offsetTint.x;
            case "tint.g":          return offsetTint.y;
            case "tint.b":          return offsetTint.z;
            case "screenTint.r":    return offsetScreenTint.x;
            case "screenTint.g":    return offsetScreenTint.y;
            case "screenTint.b":    return offsetScreenTint.z;
            default:                return super.getValue(key);
        }
    }

    bool isMaskedBy(Drawable drawable) {
        foreach(mask; masks) {
            if (mask.maskSrc.uuid == drawable.uuid) return true;
        }
        return false;
    }

    ptrdiff_t getMaskIdx(Drawable drawable) {
        if (drawable is null) return -1;
        foreach(i, ref mask; masks) {
            if (mask.maskSrc.uuid == drawable.uuid) return i;
        }
        return -1;
    }

    ptrdiff_t getMaskIdx(uint uuid) {
        foreach(i, ref mask; masks) {
            if (mask.maskSrc.uuid == uuid) return i;
        }
        return -1;
    }

    override
    void beginUpdate() {
        offsetOpacity = 1;
        offsetTint = vec3(1, 1, 1);
        offsetScreenTint = vec3(0, 0, 0);
        super.beginUpdate();
    }

    override
    void drawOne() {
        if (!enabled) return;
        
        this.selfSort();
        this.drawContents();

        size_t cMasks = maskCount;

        if (masks.length > 0) {
            inBeginMask(cMasks > 0);

            foreach(ref mask; masks) {
                mask.maskSrc.renderMask(mask.mode == MaskingMode.DodgeMask);
            }

            inBeginMaskContent();

            // We are the content
            this.drawSelf();

            inEndMask();
            return;
        }

        // No masks, draw normally
        super.drawOne();
        this.drawSelf();
    }

    override
    void draw() {
        if (!enabled) return;
        this.drawOne();
    }

    override
    void finalize() {
        super.finalize();
        
        MaskBinding[] validMasks;
        foreach(i; 0..masks.length) {
            if (Drawable nMask = puppet.find!Drawable(masks[i].maskSrcUUID)) {
                masks[i].maskSrc = nMask;
                validMasks ~= masks[i];
            }
        }

        // Remove invalid masks
        masks = validMasks;
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