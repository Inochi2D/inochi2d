/*
    Inochi2D Part

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.drawable.part;
import inochi2d.core.nodes.drawable;
import inochi2d.core.format;
import inochi2d.core.math;
import inochi2d.core;

import std.exception;
import std.algorithm.mutation : copy;
import std.math : isNaN;

public import inochi2d.core.nodes.common;
public import inochi2d.core.render.state;
public import inochi2d.core.mesh;

enum NO_TEXTURE = uint.max;
enum TextureUsage : size_t {
    Albedo,
    Emissive,
    Bumpmap,
    COUNT
}

struct PartVars {
align(vec4.sizeof):
    vec3 tint;
    vec3 screenTint;
    float opacity;
    float emissionStrength;
}

/**
    Dynamic Mesh Part
*/
@TypeId("Part", 0x0101)
class Part : Drawable {
private:
protected:

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void onSerialize(ref JSONValue object, bool recursive = true) {
        super.onSerialize(object, recursive);

        object["textures"] = JSONValue.emptyArray;
        foreach(ref texture; textures) {
            if (texture) {
                ptrdiff_t index = puppet.getTextureSlotIndexFor(texture);
                object["textures"].array ~= JSONValue(index >= 0 ? index : NO_TEXTURE);
            } else {
                object["textures"].array ~= JSONValue(NO_TEXTURE);
            }
        }

        object["blend_mode"] = blendingMode;
        object["tint"] = tint.serialize();
        object["screenTint"] = screenTint.serialize();
        object["emissionStrength"] = emissionStrength;
        object["masks"] = masks.serialize();
        object["opacity"] = opacity;
    }

    override
    void onDeserialize(ref JSONValue object) {
        super.onDeserialize(object);

        if (object.isJsonArray("textures")) {
            import std.stdio : writeln;
            foreach(i, ref JSONValue element; object["textures"].array) {

                uint textureId = element.tryGet!uint(NO_TEXTURE);
                if (textureId == NO_TEXTURE) continue;

                // TODO: Abstract this to properly handle refcounts.
                this.textures[i] = puppet.textureCache.get(textureId);
                if (this.textures[i])
                    this.textures[i].retain();
            }
        }
        
        object.tryGetRef(opacity, "opacity");
        object.tryGetRef(tint, "tint");
        object.tryGetRef(screenTint, "screenTint");
        object.tryGetRef(tint, "tint");
        object.tryGetRef(emissionStrength, "emissionStrength");
        object.tryGetRef(masks, "masks");

        blendingMode = object.tryGet!string("blend_mode", "Normal").toBlendMode();
    }

    //
    //      PARAMETER OFFSETS
    //
    float offsetMaskThreshold = 0;
    float offsetOpacity = 1;
    float offsetEmissionStrength = 1;
    vec3 offsetTint = vec3(0);
    vec3 offsetScreenTint = vec3(0);

public:
    /**
        List of textures this part can use

        TODO: use more than texture 0
    */
    Texture[IN_MAX_ATTACHMENTS] textures;

    /**
        List of masks to apply
    */
    MaskBinding[] masks;

    /**
        Blending mode
    */
    BlendMode blendingMode = BlendMode.normal;

    /**
        Opacity of the mesh
    */
    float opacity = 1;

    /**
        Strength of emission
    */
    float emissionStrength = 1;

    /**
        Multiplicative tint color
    */
    vec3 tint = vec3(1, 1, 1);

    /**
        Screen tint color
    */
    vec3 screenTint = vec3(0, 0, 0);

    /**
        Gets the active texture
    */
    Texture activeTexture() {
        return textures[0];
    }

    /// Destructor
    ~this() {
        foreach(texture; textures) {
            if (texture)
                texture.release();
        }
    }

    /**
        Constructs a new part
    */
    this(MeshData data, Texture[] textures, Node parent = null) {
        this(data, textures, inNewGUID(), parent);
    }

    /**
        Constructs a new part
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        Constructs a new part
    */
    this(MeshData data, Texture[] textures, GUID guid, Node parent = null) {
        super(data, guid, parent);
        foreach(i; 0..TextureUsage.COUNT) {
            if (i >= textures.length) break;
            this.textures[i] = textures[i];
        }
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
            case "emissionStrength":
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
            case "alphaThreshold":
                return 0;
            case "opacity":
            case "tint.r":
            case "tint.g":
            case "tint.b":
                return 1;
            case "screenTint.r":
            case "screenTint.g":
            case "screenTint.b":
                return 0;
            case "emissionStrength":
                return 1;
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
            case "emissionStrength":
                offsetEmissionStrength += value;
                return true;
            default: return false;
        }
    }
    
    override
    float getValue(string key) {
        switch(key) {
            case "opacity":             return offsetOpacity;
            case "tint.r":              return offsetTint.x;
            case "tint.g":              return offsetTint.y;
            case "tint.b":              return offsetTint.z;
            case "screenTint.r":        return offsetScreenTint.x;
            case "screenTint.g":        return offsetScreenTint.y;
            case "screenTint.b":        return offsetScreenTint.z;
            case "emissionStrength":    return offsetEmissionStrength;
            default:                    return super.getValue(key);
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
        offsetMaskThreshold = 0;
        offsetOpacity = 1;
        offsetTint = vec3(1, 1, 1);
        offsetScreenTint = vec3(0, 0, 0);
        offsetEmissionStrength = 1;
        super.preUpdate(drawList);
    }

    override
    void draw(float delta, DrawList drawList) {
        if (!renderEnabled)
            return;

        PartVars vars = PartVars(
            tint*offsetTint,
            screenTint*offsetScreenTint,
            opacity*offsetOpacity,
            emissionStrength*offsetEmissionStrength
        );
        
        if (masks.length > 0) {
            foreach(ref mask; masks) {
                if (mask.maskSrc)
                    mask.maskSrc.drawAsMask(delta, drawList, mask.mode);
            }

            super.draw(delta, drawList);
            drawList.setDrawState(DrawState.maskedDraw);
            drawList.setVariables!PartVars(nid, vars);
            drawList.setBlending(blendingMode);
            drawList.setSources(textures);
            drawList.next();
            return;
        }

        super.draw(delta, drawList);
        drawList.setSources(textures);
        drawList.setBlending(blendingMode);
        drawList.setVariables!PartVars(nid, vars);
        drawList.next();
    }

    override
    void drawAsMask(float delta, DrawList drawList, MaskingMode mode) {
        super.drawAsMask(delta, drawList, mode);
        drawList.setDrawState(DrawState.defineMask);
        drawList.setSources(textures);
        drawList.setMasking(mode);
        drawList.next();
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
    }
}