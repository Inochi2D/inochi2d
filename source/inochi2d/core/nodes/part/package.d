/*
    Inochi2D Part

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.part;
import inochi2d.core.render.ftable;
import inochi2d.integration;
import inochi2d.fmt;
import inochi2d.core.nodes.drawable;
import inochi2d.core;
import inochi2d.math;
import bindbc.opengl;
import std.exception;
import std.algorithm.mutation : copy;
public import inochi2d.core.nodes.common;
import std.math : isNaN;

public import inochi2d.core.meshdata;


package(inochi2d) {
    void inInitPart() {
        inRegisterNodeType!Part;
    }
}

// struct PartRenderData {
//     float* vtxdata;
//     MeshData* meshData;
// }

/**
    Creates a simple part that is sized after the texture given
    part is created based on file path given.
    Supported file types are: png, tga and jpeg

    This is unoptimal for normal use and should only be used
    for real-time use when you want to add/remove parts on the fly
*/
Part inCreateSimplePart(string file, Node parent = null) {
    return inCreateSimplePart(TextureData(file), parent, file);
}

/**
    Creates a simple part that is sized after the texture given

    This is unoptimal for normal use and should only be used
    for real-time use when you want to add/remove parts on the fly
*/
Part inCreateSimplePart(TextureData texture, Node parent = null, string name = "New Part") {
	return inCreateSimplePart(new RuntimeTexture(texture), parent, name);
}

/**
    Creates a simple part that is sized after the texture given

    This is unoptimal for normal use and should only be used
    for real-time use when you want to add/remove parts on the fly
*/
Part inCreateSimplePart(RuntimeTexture* tex, Node parent = null, string name = "New Part") {
	float twidth = tex.width;
    float theight = tex.height;
    
    MeshData data = MeshData([
		vec2(-(twidth/2), -(theight/2)),
		vec2(-(twidth/2), theight/2),
		vec2(twidth/2, -(theight/2)),
		vec2(twidth/2, theight/2),
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
    InRenderData renderData;

    /*
        RENDERING
    */
    void drawSelf(bool isMask = false)() {
        inRenderSubmit(IN_PART, &renderData);
    }

protected:

    override
    string typeId() { return "Part"; }

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void serializeSelfImpl(ref InochiSerializer serializer, bool recursive = true) {
        super.serializeSelfImpl(serializer, recursive);

        // TODO: Allow this again?
        enforce(inIsINPMode(), "Can't serialize from raw JSON.");

        serializer.putKey("textures");
        auto state = serializer.arrayBegin();
        foreach(ref texture; textures) {
            if (texture) {
                ptrdiff_t index = puppet.getTextureSlotIndexFor(texture);
                if (index >= 0) {
                    serializer.elemBegin;
                    serializer.putValue(cast(size_t)index);
                } else {
                    serializer.elemBegin;
                    serializer.putValue(cast(size_t)NO_TEXTURE);
                }
            } else {
                serializer.elemBegin;
                serializer.putValue(cast(size_t)NO_TEXTURE);
            }
        }
        serializer.arrayEnd(state);

        serializer.putKey("blend_mode");
        serializer.serializeValue(blendingMode);
        
        serializer.putKey("tint");
        tint.serialize(serializer);

        serializer.putKey("screenTint");
        screenTint.serialize(serializer);

        serializer.putKey("emissionStrength");
        serializer.serializeValue(emissionStrength);

        if (masks.length > 0) {
            serializer.putKey("masks");
            state = serializer.arrayBegin();
                foreach(m; masks) {
                    serializer.elemBegin;
                    serializer.serializeValue(m);
                }
            serializer.arrayEnd(state);
        }

        serializer.putKey("mask_threshold");
        serializer.putValue(maskAlphaThreshold);

        serializer.putKey("opacity");
        serializer.putValue(opacity);
    }

    override
    SerdeException deserializeFromFghj(Fghj data) {
        super.deserializeFromFghj(data);

        // TODO: Allow this again?
        enforce(inIsINPMode(), "Can't deserialize from raw JSON.");

        foreach(texElement; data["textures"].byElement) {
            uint textureId;
            texElement.deserializeValue(textureId);
            if (textureId == NO_TEXTURE) continue;

            textureIds ~= textureId;
        }

        data["opacity"].deserializeValue(this.opacity);
        data["mask_threshold"].deserializeValue(this.maskAlphaThreshold);

        // Older models may not have tint
        if (!data["tint"].isEmpty) deserialize(tint, data["tint"]);

        // Older models may not have screen tint
        if (!data["screenTint"].isEmpty) deserialize(screenTint, data["screenTint"]);

        // Older models may not have emission
        if (!data["emissionStrength"].isEmpty) deserialize(tint, data["emissionStrength"]);

        // Older models may not have blend mode
        if (!data["blend_mode"].isEmpty) data["blend_mode"].deserializeValue(this.blendingMode);

        if (!data["masked_by"].isEmpty) {
            MaskingMode mode;
            data["mask_mode"].deserializeValue(mode);

            // Go every masked part
            foreach(imask; data["masked_by"].byElement) {
                uint uid;
                if (auto exc = imask.deserializeValue(uid)) return exc;
                this.masks ~= MaskBinding(uid, mode, null);
            }
        }

        if (!data["masks"].isEmpty) {
            data["masks"].deserializeValue(this.masks);
        }

        return null;
    }

    override
    void serializePartial(ref InochiSerializer serializer, bool recursive=true) {
        super.serializePartial(serializer, recursive);
        serializer.putKey("textureUIDs");
        auto state = serializer.arrayBegin();
            foreach(ref texture; textures) {
                uint uid;
                if (texture !is null) {
                    uid = texture.uid;                                    
                } else {
                    uid = InInvalidUID;
                }
                serializer.elemBegin;
                serializer.putValue(cast(size_t)uid);
            }
        serializer.arrayEnd(state);
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
        foreach(m; masks) if (m.mode == MaskingMode.Mask) c++;
        return c;
    }

    size_t dodgeCount() {
        size_t c;
        foreach(m; masks) if (m.mode == MaskingMode.DodgeMask) c++;
        return c;
    }

public:
    /**
        Runtime textures associated with this part
    */
    RuntimeTexture*[TextureUsage.COUNT] textures;

    /**
        List of texture IDs
    */
    uint[] textureIds;

    /**
        List of masks to apply
    */
    MaskBinding[] masks;

    /**
        Blending mode
    */
    BlendMode blendingMode = BlendMode.Normal;
    
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

    ~this() {
        inRenderNodeCleanup(IN_PART, &renderData);
    }

    /**
        Constructs a new part
    */
    this(MeshData data, RuntimeTexture*[] textures, Node parent = null) {
        this(data, textures, inCreateUID(), parent);
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
    this(MeshData data, RuntimeTexture*[] textures, uint uid, Node parent = null) {
        super(data, uid, parent);
        foreach(i; 0..TextureUsage.COUNT) {
            if (i >= textures.length) break;
            this.textures[i] = textures[i];
        }
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
                offsetScreenTint.x *= value;
                return true;
            case "screenTint.g":
                offsetScreenTint.y *= value;
                return true;
            case "screenTint.b":
                offsetScreenTint.z *= value;
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
            if (mask.maskSrc.uid == drawable.uid) return true;
        }
        return false;
    }

    ptrdiff_t getMaskIdx(Drawable drawable) {
        if (drawable is null) return -1;
        foreach(i, ref mask; masks) {
            if (mask.maskSrc.uid == drawable.uid) return i;
        }
        return -1;
    }

    ptrdiff_t getMaskIdx(uint uid) {
        foreach(i, ref mask; masks) {
            if (mask.maskSrc.uid == uid) return i;
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
    void rebuffer(ref MeshData data) {
        super.rebuffer(data);
        inRenderNodeUpdate(IN_PART, &renderData);
    }

    override
    void draw() {
        if (!enabled) return;
        this.drawOne();

        foreach(child; children) {
            child.draw();
        }
    }

    override
    void drawOne() {
        if (!enabled) return;
        if (!data.isReady) return; // Yeah, don't even try
        
        size_t cMasks = maskCount;

        if (masks.length > 0) {
            import std.stdio : writeln;
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
        this.drawSelf();
    
        super.drawOne();
    }

    override
    void drawOneDirect(bool forMasking) {
        if (forMasking) this.drawSelf!true();
        else this.drawSelf!false();
    }

    override
    void finalize() {
        super.finalize();
        
        MaskBinding[] validMasks;
        foreach(i; 0..masks.length) {
            if (Drawable nMask = puppet.find!Drawable(masks[i].maskSrcUID)) {
                masks[i].maskSrc = nMask;
                validMasks ~= masks[i];
            }
        }

        inRenderNodeFinalize(IN_PART, &renderData);

        // Remove invalid masks
        masks = validMasks;
    }


    override
    void setOneTimeTransform(mat4* transform) {
        super.setOneTimeTransform(transform);
        foreach (m; masks) {
            m.maskSrc.oneTimeTransform = transform;
        }
    }

    /**
        The render ID of the node
    */
    override
    ubyte getRenderId() { return RenderID.Part; }
}

// /**
//     Draws a texture at the transform of the specified part
// */
// deprecated("Not available at current time, does nothing")
// void inDrawTextureAtPart(RuntimeTexture* texture, Part part) {
//     // const float texWidthP = texture.getWidth()/2;
//     // const float texHeightP = texture.getHeight()/2;

//     // // Bind the vertex array
//     // incDrawableBindVAO();

//     // partShader.use();
//     // partShader.setUniform(mvp, 
//     //     inGetCamera().matrix * 
//     //     mat4.translation(vec3(part.transform.matrix() * vec4(1, 1, 1, 1)))
//     // );
//     // partShader.setUniform(gopacity, part.opacity);
//     // partShader.setUniform(gMultColor, part.tint);
//     // partShader.setUniform(gScreenColor, part.screenTint);
    
//     // // Bind the texture
//     // texture.bind();

//     // // Enable points array
//     // glEnableVertexAttribArray(0);
//     // glBindBuffer(GL_ARRAY_BUFFER, sVertexBuffer);
//     // glBufferData(GL_ARRAY_BUFFER, 4*vec2.sizeof, [
//     //     -texWidthP, -texHeightP,
//     //     texWidthP, -texHeightP,
//     //     -texWidthP, texHeightP,
//     //     texWidthP, texHeightP,
//     // ].ptr, GL_STATIC_DRAW);
//     // glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

//     // // Enable UVs array
//     // glEnableVertexAttribArray(1); // uvs
//     // glBindBuffer(GL_ARRAY_BUFFER, sUVBuffer);
//     // glBufferData(GL_ARRAY_BUFFER, 4*vec2.sizeof, [
//     //     0, 0,
//     //     1, 0,
//     //     0, 1,
//     //     1, 1,
//     // ].ptr, GL_STATIC_DRAW);
//     // glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

//     // // Bind element array and draw our mesh
//     // glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, sElementBuffer);
//     // glBufferData(GL_ELEMENT_ARRAY_BUFFER, 6*ushort.sizeof, (cast(ushort[])[
//     //     0u, 1u, 2u,
//     //     2u, 1u, 3u
//     // ]).ptr, GL_STATIC_DRAW);
//     // glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, null);

//     // // Disable the vertex attribs after use
//     // glDisableVertexAttribArray(0);
//     // glDisableVertexAttribArray(1);
// }

// /**
//     Draws a texture at the transform of the specified part
// */
// deprecated("Not available at current time, does nothing")
// void inDrawTextureAtPosition(RuntimeTexture* texture, vec2 position, float opacity = 1, vec3 color = vec3(1, 1, 1), vec3 screenColor = vec3(0, 0, 0)) {
//     // const float texWidthP = texture.getWidth()/2;
//     // const float texHeightP = texture.getHeight()/2;

//     // // Bind the vertex array
//     // incDrawableBindVAO();

//     // partShader.use();
//     // partShader.setUniform(mvp, 
//     //     inGetCamera().matrix * 
//     //     mat4.scaling(1, 1, 1) * 
//     //     mat4.translation(vec3(position, 0))
//     // );
//     // partShader.setUniform(gopacity, opacity);
//     // partShader.setUniform(gMultColor, color);
//     // partShader.setUniform(gScreenColor, screenColor);
    
//     // // Bind the texture
//     // texture.bind();

//     // // Enable points array
//     // glEnableVertexAttribArray(0);
//     // glBindBuffer(GL_ARRAY_BUFFER, sVertexBuffer);
//     // glBufferData(GL_ARRAY_BUFFER, 4*vec2.sizeof, [
//     //     -texWidthP, -texHeightP,
//     //     texWidthP, -texHeightP,
//     //     -texWidthP, texHeightP,
//     //     texWidthP, texHeightP,
//     // ].ptr, GL_STATIC_DRAW);
//     // glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

//     // // Enable UVs array
//     // glEnableVertexAttribArray(1); // uvs
//     // glBindBuffer(GL_ARRAY_BUFFER, sUVBuffer);
//     // glBufferData(GL_ARRAY_BUFFER, 4*vec2.sizeof, (cast(float[])[
//     //     0, 0,
//     //     1, 0,
//     //     0, 1,
//     //     1, 1,
//     // ]).ptr, GL_STATIC_DRAW);
//     // glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

//     // // Bind element array and draw our mesh
//     // glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, sElementBuffer);
//     // glBufferData(GL_ELEMENT_ARRAY_BUFFER, 6*ushort.sizeof, (cast(ushort[])[
//     //     0u, 1u, 2u,
//     //     2u, 1u, 3u
//     // ]).ptr, GL_STATIC_DRAW);
//     // glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, null);

//     // // Disable the vertex attribs after use
//     // glDisableVertexAttribArray(0);
//     // glDisableVertexAttribArray(1);
// }

// /**
//     Draws a texture at the transform of the specified part
// */
// deprecated("Not available at current time, does nothing")
// void inDrawTextureAtRect(RuntimeTexture* texture, rect area, rect uvs = rect(0, 0, 1, 1), float opacity = 1, vec3 color = vec3(1, 1, 1), vec3 screenColor = vec3(0, 0, 0), Shader s = null, Camera cam = null) {

//     // // Bind the vertex array
//     // incDrawableBindVAO();

//     // if (!s) s = partShader;
//     // if (!cam) cam = inGetCamera();
//     // s.use();
//     // s.setUniform(s.getUniformLocation("mvp"), 
//     //     cam.matrix * 
//     //     mat4.scaling(1, 1, 1)
//     // );
//     // s.setUniform(s.getUniformLocation("opacity"), opacity);
//     // s.setUniform(s.getUniformLocation("multColor"), color);
//     // s.setUniform(s.getUniformLocation("screenColor"), screenColor);
    
//     // // Bind the texture
//     // texture.bind();

//     // // Enable points array
//     // glEnableVertexAttribArray(0);
//     // glBindBuffer(GL_ARRAY_BUFFER, sVertexBuffer);
//     // glBufferData(GL_ARRAY_BUFFER, 4*vec2.sizeof, [
//     //     area.left, area.top,
//     //     area.right, area.top,
//     //     area.left, area.bottom,
//     //     area.right, area.bottom,
//     // ].ptr, GL_STATIC_DRAW);
//     // glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

//     // // Enable UVs array
//     // glEnableVertexAttribArray(1); // uvs
//     // glBindBuffer(GL_ARRAY_BUFFER, sUVBuffer);
//     // glBufferData(GL_ARRAY_BUFFER, 4*vec2.sizeof, (cast(float[])[
//     //     uvs.x, uvs.y,
//     //     uvs.getWidth, uvs.y,
//     //     uvs.x, uvs.getHeight,
//     //     uvs.getWidth, uvs.getHeight,
//     // ]).ptr, GL_STATIC_DRAW);
//     // glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

//     // // Bind element array and draw our mesh
//     // glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, sElementBuffer);
//     // glBufferData(GL_ELEMENT_ARRAY_BUFFER, 6*ushort.sizeof, (cast(ushort[])[
//     //     0u, 1u, 2u,
//     //     2u, 1u, 3u
//     // ]).ptr, GL_STATIC_DRAW);
//     // glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, null);

//     // // Disable the vertex attribs after use
//     // glDisableVertexAttribArray(0);
//     // glDisableVertexAttribArray(1);
// }