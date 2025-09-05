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
import inochi2d.core.math;
import inochi2d.core;

import std.exception;
import std.algorithm.sorting;

public import inochi2d.core.render.state;
import numem;

/**
    Composite Node
*/
@TypeId("Composite")
class Composite : Node {
private:
    Texture[IN_MAX_ATTACHMENTS] _colors;
    Texture                     _depthStencil;

    void drawContents(float delta, DrawList drawList) {

        // Optimization: Nothing to be drawn, skip context switching
        if (subParts.length == 0) return;

        foreach(Part child; subParts) {
            child.draw(delta, drawList);
        }
    }

    void selfSort() {
        import std.math : cmp;
        sort!((a, b) => cmp(
            a.zSort, 
            b.zSort) > 0)(subParts);
    }

    void scanPartsRecurse(Node node) {

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

    override
    void onSerialize(ref JSONValue object, bool recursive=true) {
        super.onSerialize(object, recursive);
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

    override
    void finalize() {
        super.finalize();
        
        MaskBinding[] validMasks;
        foreach(i; 0..masks.length) {
            if (Drawable nMask = puppet.find!Drawable(masks[i].maskSrcGUID)) {
                masks[i].maskSrc = nMask;
                validMasks ~= masks[i];
            }
        }

        // Remove invalid masks
        masks = validMasks;

        // Textures should be allocated outside of the GC, the cache
        // ends up owning them.
        _depthStencil = nogc_new!Texture(32, 32, TextureFormat.depthStencil);
        _depthStencil.retain();
        puppet.textureCache.add(_depthStencil);
        foreach(i; 0.._colors.length) {
            _colors[i] = nogc_new!Texture(32, 32, TextureFormat.rgba8Unorm);
            _colors[i].retain();

            puppet.textureCache.add(_colors[i]);
        }
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
        foreach(m; masks) if (m.mode == MaskingMode.mask) c++;
        return c;
    }

    size_t dodgeCount() {
        size_t c;
        foreach(m; masks) if (m.mode == MaskingMode.dodge) c++;
        return c;
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

    /// Destructor
    ~this() {
        foreach(texture; _colors) {
            if (texture)
                texture.release();
        }
        _depthStencil.release();
    }

    /**
        Constructs a new mask
    */
    this(Node parent = null) {
        this(inNewGUID(), parent);
    }

    /**
        Constructs a new composite
    */
    this(GUID guid, Node parent = null) {
        super(guid, parent);
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
            if (mask.maskSrc.guid == drawable.guid) return true;
        }
        return false;
    }

    ptrdiff_t getMaskIdx(Drawable drawable) {
        if (drawable is null) return -1;
        foreach(i, ref mask; masks) {
            if (mask.maskSrc.guid == drawable.guid) return i;
        }
        return -1;
    }

    ptrdiff_t getMaskIdx(GUID guid) {
        foreach(i, ref mask; masks) {
            if (mask.maskSrc.guid == guid) return i;
        }
        return -1;
    }

    override
    void preUpdate(DrawList drawList) {
        offsetOpacity = 1;
        offsetTint = vec3(1, 1, 1);
        offsetScreenTint = vec3(0, 0, 0);
        super.preUpdate(drawList);
    }

    override
    void draw(float delta, DrawList drawList) {
        if (!enabled) return;
        
        this.selfSort();
        this.drawContents(delta, drawList);

        size_t cMasks = maskCount;
        if (masks.length > 0) {
        //     // inBeginMask(cMasks > 0);

        //     foreach(ref mask; masks) {
        //         mask.maskSrc.renderMask(mask.mode == MaskingMode.dodge);
        //     }

        //     // inBeginMaskContent();

        //     // We are the content
        //     this.drawSelf();

        //     // inEndMask();
            return;
        }
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