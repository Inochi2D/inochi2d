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
class Part : Visual, IDeformable {
private:
    Mesh mesh_;
    DeformedMesh deformed_;
    DeformedMesh base_;

protected:

    /**
        The current active draw list slot for this
        drawable.
    */
    DrawListAlloc* drawListSlot;

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void onSerialize(ref JSONValue object, bool recursive = true) {
        super.onSerialize(object, recursive);

        MeshData data = mesh_.toMeshData();
        object["mesh"] = data.serialize();
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

        this.deformed_ = nogc_new!DeformedMesh();
        this.base_ = nogc_new!DeformedMesh();
        this.mesh = Mesh.fromMeshData(object.tryGet!MeshData("mesh"));
        if (object.isJsonArray("textures")) {
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
        The mesh of the part..
    */
    final @property Mesh mesh() @nogc => mesh_;
    final @property void mesh(Mesh value) @nogc {
        if (value is mesh_)
            return;
        
        if (mesh_)
            mesh_.release();

        this.mesh_ = value.retained();
        this.deformed_.parent = value;
        this.base_.parent = value;
    }

    /**
        Local matrix of the deformable object.
    */
    override @property Transform baseTransform() @nogc => transform!true;

    /**
        World matrix of the deformable object.
    */
    override @property Transform worldTransform() @nogc => transform!false;

    /**
        The base position of the deformable's points.
    */
    @property const(vec2)[] basePoints() => base_.points;

    /**
        The points which may be deformed by the deformer.
    */
    override @property vec2[] deformPoints() => deformed_.points;

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
        mesh_.release();
        nogc_delete(deformed_);
        foreach(texture; textures) {
            if (texture)
                texture.release();
        }
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
    this(MeshData data, Node parent = null) {
        this(data, inNewGUID(), parent);
    }

    /**
        Constructs a new part
    */
    this(MeshData data, GUID guid, Node parent = null) {
        super(guid, parent);
        
        this.deformed_ = nogc_new!DeformedMesh();
        this.base_ = nogc_new!DeformedMesh();
        this.mesh = Mesh.fromMeshData(data);
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
    this(MeshData data, Texture[] textures, GUID guid, Node parent = null) {
        super(data, guid, parent);
        foreach(i; 0..TextureUsage.COUNT) {
            if (i >= textures.length) break;
            this.textures[i] = textures[i];
        }
    }

    /**
        Resets the deformation for the IDeformable.
    */
    override
    void resetDeform() {
        deformed_.reset();
        
        base_.reset();
        base_.pushMatrix(baseTransform.matrix);
    }

    /**
        Deforms the IDeformable.

        Params:
            deformed =  The deformation delta.
            absolute =  Whether the deformation is absolute,
                        replacing the original deformation.
    */
    override
    void deform(vec2[] deformed, bool absolute = false) {
        deformed_.deform(deformed);
    }
    
    /**
        Deforms a single vertex in the IDeformable

        Params:
            offset =    The offset into the point list to deform.
            deform =    The deformation delta.
            absolute =  Whether the deformation is absolute,
                        replacing the original deformation.
    */
    override void deform(size_t offset, vec2 deform, bool absolute = false) {
        deformed_.deform(offset, deform);
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
        this.resetDeform();
    }

    /**
        Updates the drawable
    */
    override
    void update(float delta, DrawList drawList) {
        super.update(delta, drawList);
        deformed_.pushMatrix(transform.matrix);
    }

    /**
        Post-update
    */
    override
    void postUpdate(DrawList drawList) {
        super.postUpdate(drawList);
        this.drawListSlot = drawList.allocate(deformed_.vertices, deformed_.indices);
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

            drawList.setMesh(drawListSlot);
            drawList.setDrawState(DrawState.maskedDraw);
            drawList.setVariables!PartVars(nid, vars);
            drawList.setBlending(blendingMode);
            drawList.setSources(textures);
            drawList.next();
            return;
        }

        drawList.setMesh(drawListSlot);
        drawList.setSources(textures);
        drawList.setBlending(blendingMode);
        drawList.setVariables!PartVars(nid, vars);
        drawList.next();
    }

    override
    void drawAsMask(float delta, DrawList drawList, MaskingMode mode) {
        drawList.setMesh(drawListSlot);
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
mixin Register!(Part, in_node_registry);
