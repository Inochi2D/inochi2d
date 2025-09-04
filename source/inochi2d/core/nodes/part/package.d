/*
    Inochi2D Part

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.part;
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

/**
    Creates a simple part that is sized after the texture given
    part is created based on file path given.
    Supported file types are: png, tga and jpeg

    This is unoptimal for normal use and should only be used
    for real-time use when you want to add/remove parts on the fly
*/
Part inCreateSimplePart(string file, Node parent = null) {
    // return inCreateSimplePart(TextureData.load(file), parent, file);
    return null;
}

/**
    Creates a simple part that is sized after the texture given

    This is unoptimal for normal use and should only be used
    for real-time use when you want to add/remove parts on the fly
*/
Part inCreateSimplePart(TextureData texture, Node parent = null, string name = "New Part") {
	return inCreateSimplePart(Texture.createForData(texture), parent, name);
}

/**
    Creates a simple part that is sized after the texture given

    This is unoptimal for normal use and should only be used
    for real-time use when you want to add/remove parts on the fly
*/
Part inCreateSimplePart(Texture tex, Node parent = null, string name = "New Part") {
	MeshData data = MeshData([
		vec2(-(tex.width/2), -(tex.height/2)),
		vec2(-(tex.width/2), tex.height/2),
		vec2(tex.width/2, -(tex.height/2)),
		vec2(tex.width/2, tex.height/2),
	], 
	[
		vec2(0, 0),
		vec2(0, 1),
		vec2(1, 0),
		vec2(1, 1),
	],
	[
		0, 1, 2,
		2, 1, 3
	]);
	Part p = new Part(data, [tex], parent);
	p.name = name;
    return p;
}

enum NO_TEXTURE = uint.max;

enum TextureUsage : size_t {
    Albedo,
    Emissive,
    Bumpmap,
    COUNT
}

/**
    Dynamic Mesh Part
*/
@TypeId("Part")
class Part : Drawable {
private:
protected:

    override
    string typeId() { return "Part"; }

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
        object["mask_threshold"] = maskAlphaThreshold;
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
        object.tryGetRef(maskAlphaThreshold, "mask_threshold");
        object.tryGetRef(tint, "tint");
        object.tryGetRef(screenTint, "screenTint");
        object.tryGetRef(tint, "tint");
        object.tryGetRef(emissionStrength, "emissionStrength");
        object.tryGetRef(masks, "masks");

        blendingMode = object.tryGet!string("blend_mode", "Normal").toBlendMode();
        if (object.isJsonArray("masked_by")) {

            // Go to every masked part
            MaskingMode mode = object.tryGet!string("mask_mode").toMaskingMode;
            foreach(imask; object["masked_by"].array) {
                GUID guid = imask.tryGetGUID();
                this.masks ~= MaskBinding(guid, mode, null);
            }
        }

        // Update indices and vertices
        // this.updateUVs();
    }

    //
    //      PARAMETER OFFSETS
    //
    float offsetMaskThreshold = 0;
    float offsetOpacity = 1;
    float offsetEmissionStrength = 1;
    vec3 offsetTint = vec3(0);
    vec3 offsetScreenTint = vec3(0);

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
    /**
        List of textures this part can use

        TODO: use more than texture 0
    */
    Texture[TextureUsage.COUNT] textures;

    /**
        List of masks to apply
    */
    MaskBinding[] masks;

    /**
        Blending mode
    */
    BlendMode blendingMode = BlendMode.normal;
    
    /**
        Alpha Threshold for the masking system, the higher the more opaque pixels will be discarded in the masking process
    */
    float maskAlphaThreshold = 0.5;

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
        
        // this.updateUVs();
    }
    
    override
    void renderMask(bool dodge = false) {

    }

    override
    bool hasParam(string key) {
        if (super.hasParam(key)) return true;

        switch(key) {
            case "alphaThreshold":
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
            case "alphaThreshold":
                offsetMaskThreshold *= value;
                return true;
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
            case "alphaThreshold":  return offsetMaskThreshold;
            case "opacity":         return offsetOpacity;
            case "tint.r":          return offsetTint.x;
            case "tint.g":          return offsetTint.y;
            case "tint.b":          return offsetTint.z;
            case "screenTint.r":    return offsetScreenTint.x;
            case "screenTint.g":    return offsetScreenTint.y;
            case "screenTint.b":    return offsetScreenTint.z;
            case "emissionStrength":    return offsetEmissionStrength;
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
    void beginUpdate() {
        offsetMaskThreshold = 0;
        offsetOpacity = 1;
        offsetTint = vec3(1, 1, 1);
        offsetScreenTint = vec3(0, 0, 0);
        offsetEmissionStrength = 1;
        super.beginUpdate();
    }

    override
    void draw(float delta) {
        if (!enabled) return;
        this.drawOne(delta);

        foreach(child; children) {
            child.draw(delta);
        }
    }

    override
    void drawOne(float delta) {
        if (!enabled) return;
        
        size_t cMasks = maskCount;
        if (masks.length > 0) {
            // inBeginMask(cMasks > 0);

            // foreach(ref mask; masks) {
            //     mask.maskSrc.renderMask(mask.mode == MaskingMode.DodgeMask);
            // }

            // inBeginMaskContent();

            // // We are the content
            // this.drawSelf();

            // inEndMask();
            return;
        }

        // No masks, draw normally
        // this.drawSelf();
        super.drawOne(delta);
    }

    override
    void drawOneDirect(bool forMasking) {
        // if (forMasking) this.drawSelf!true();
        // else this.drawSelf!false();
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