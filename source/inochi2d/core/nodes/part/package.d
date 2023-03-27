/*
    Inochi2D Part

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.part;
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
    private {
        Texture boundAlbedo;

        Shader partShader;
        Shader partMaskShader;

        /* GLSL Uniforms (Normal) */
        GLint mvp;
        GLint offset;
        GLint gopacity;
        GLint gMultColor;
        GLint gScreenColor;
        GLint gEmissionStrength;

        /* GLSL Uniforms (Masks) */
        GLint mmvp;
        GLint mthreshold;

        GLuint sVertexBuffer;
        GLuint sUVBuffer;
        GLuint sElementBuffer;
    }

    void inInitPart() {
        inRegisterNodeType!Part;

        version(InDoesRender) {
            partShader = new Shader(import("basic/basic.vert"), import("basic/basic.frag"));
            partMaskShader = new Shader(import("basic/basic.vert"), import("basic/basic-mask.frag"));

            incDrawableBindVAO();

            partShader.use();
            partShader.setUniform(partShader.getUniformLocation("albedo"), 0);
            partShader.setUniform(partShader.getUniformLocation("emissive"), 1);
            partShader.setUniform(partShader.getUniformLocation("bumpmap"), 2);
            mvp = partShader.getUniformLocation("mvp");
            offset = partShader.getUniformLocation("offset");
            gopacity = partShader.getUniformLocation("opacity");
            gMultColor = partShader.getUniformLocation("multColor");
            gScreenColor = partShader.getUniformLocation("screenColor");
            gEmissionStrength = partShader.getUniformLocation("emissionStrength");

            partMaskShader.use();
            partMaskShader.setUniform(partMaskShader.getUniformLocation("albedo"), 0);
            partMaskShader.setUniform(partMaskShader.getUniformLocation("emissive"), 1);
            partMaskShader.setUniform(partMaskShader.getUniformLocation("bumpmap"), 2);
            mmvp = partMaskShader.getUniformLocation("mvp");
            mthreshold = partMaskShader.getUniformLocation("threshold");
            
            glGenBuffers(1, &sVertexBuffer);
            glGenBuffers(1, &sUVBuffer);
            glGenBuffers(1, &sElementBuffer);
        }
    }
}


/**
    Creates a simple part that is sized after the texture given
    part is created based on file path given.
    Supported file types are: png, tga and jpeg

    This is unoptimal for normal use and should only be used
    for real-time use when you want to add/remove parts on the fly
*/
Part inCreateSimplePart(string file, Node parent = null) {
    return inCreateSimplePart(ShallowTexture(file), parent, file);
}

/**
    Creates a simple part that is sized after the texture given

    This is unoptimal for normal use and should only be used
    for real-time use when you want to add/remove parts on the fly
*/
Part inCreateSimplePart(ShallowTexture texture, Node parent = null, string name = "New Part") {
	return inCreateSimplePart(new Texture(texture), parent, name);
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
    GLuint uvbo;

    void updateUVs() {
        version(InDoesRender) {
            glBindBuffer(GL_ARRAY_BUFFER, uvbo);
            glBufferData(GL_ARRAY_BUFFER, data.uvs.length*vec2.sizeof, data.uvs.ptr, GL_STATIC_DRAW);
        }
    }

    /*
        RENDERING
    */
    void drawSelf(bool isMask = false)() {

        // In some cases this may happen
        if (textures.length == 0) return;

        // Bind the vertex array
        incDrawableBindVAO();
        mat4 matrix = transform.matrix();
        if (overrideTransformMatrix !is null)
            matrix = overrideTransformMatrix.matrix;
        if (oneTimeTransform !is null)
            matrix = (*oneTimeTransform) * matrix;
        static if (isMask) {
            partMaskShader.use();
            partMaskShader.setUniform(offset, data.origin);
            partMaskShader.setUniform(mmvp, inGetCamera().matrix * puppet.transform.matrix * matrix);
            partMaskShader.setUniform(mthreshold, clamp(offsetMaskThreshold + maskAlphaThreshold, 0, 1));
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        } else {
            partShader.use();
            partShader.setUniform(offset, data.origin);
            partShader.setUniform(mvp, inGetCamera().matrix * puppet.transform.matrix * matrix);
            partShader.setUniform(gopacity, clamp(offsetOpacity * opacity, 0, 1));
            partShader.setUniform(gEmissionStrength, emissionStrength*offsetEmissionStrength);

            partShader.setUniform(partShader.getUniformLocation("albedo"), 0);
            partShader.setUniform(partShader.getUniformLocation("emissive"), 1);
            partShader.setUniform(partShader.getUniformLocation("bumpmap"), 2);
            
            vec3 clampedColor = tint;
            if (!offsetTint.x.isNaN) clampedColor.x = clamp(tint.x*offsetTint.x, 0, 1);
            if (!offsetTint.y.isNaN) clampedColor.y = clamp(tint.y*offsetTint.y, 0, 1);
            if (!offsetTint.z.isNaN) clampedColor.z = clamp(tint.z*offsetTint.z, 0, 1);
            partShader.setUniform(gMultColor, clampedColor);

            clampedColor = screenTint;
            if (!offsetScreenTint.x.isNaN) clampedColor.x = clamp(screenTint.x+offsetScreenTint.x, 0, 1);
            if (!offsetScreenTint.y.isNaN) clampedColor.y = clamp(screenTint.y+offsetScreenTint.y, 0, 1);
            if (!offsetScreenTint.z.isNaN) clampedColor.z = clamp(screenTint.z+offsetScreenTint.z, 0, 1);
            partShader.setUniform(gScreenColor, clampedColor);
            inSetBlendMode(blendingMode);

            // TODO: EXT MODE
        }

        // Make sure we check whether we're already bound
        // Otherwise we're wasting GPU resources
        if (boundAlbedo != textures[0]) {

            // Bind the textures
            foreach(i, ref texture; textures) {
                if (texture) texture.bind(cast(uint)i);
                else {

                    // Disable texture when none is there.
                    glActiveTexture(GL_TEXTURE0+cast(uint)i);
                    glBindTexture(GL_TEXTURE_2D, 0);
                }
            }
        }
        

        // Enable points array
        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Enable UVs array
        glEnableVertexAttribArray(1); // uvs
        glBindBuffer(GL_ARRAY_BUFFER, uvbo);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Enable deform array
        glEnableVertexAttribArray(2); // deforms
        glBindBuffer(GL_ARRAY_BUFFER, dbo);
        glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Bind index buffer
        this.bindIndex();

        // Disable the vertex attribs after use
        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
        glDisableVertexAttribArray(2);
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
        version (InDoesRender) {
            if (inIsINPMode()) {
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
            }
        }

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
            auto state = serializer.arrayBegin();
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

    
        version(InRenderless) {
            if (inIsINPMode()) {
                foreach(texElement; data["textures"].byElement) {
                    uint textureId;
                    texElement.deserializeValue(textureId);
                    if (textureId == NO_TEXTURE) continue;

                    textureIds ~= textureId;
                }
            } else {
                assert(0, "Raw Inochi2D JSON not supported in renderless mode");
            }
            
            // Do nothing in this instance
        } else {
            if (inIsINPMode()) {

                size_t i;
                foreach(texElement; data["textures"].byElement) {
                    uint textureId;
                    texElement.deserializeValue(textureId);

                    // uint max = no texture set
                    if (textureId == NO_TEXTURE) continue;

                    textureIds ~= textureId;
                    this.textures[i++] = inGetTextureFromId(textureId);
                }
            } else {
                enforce(0, "Loading from texture path is deprecated.");
            }
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
                uint uuid;
                if (auto exc = imask.deserializeValue(uuid)) return exc;
                this.masks ~= MaskBinding(uuid, mode, null);
            }
        }

        if (!data["masks"].isEmpty) {
            data["masks"].deserializeValue(this.masks);
        }

        // Update indices and vertices
        this.updateUVs();
        return null;
    }

    override
    void serializePartial(ref InochiSerializer serializer, bool recursive=true) {
        super.serializePartial(serializer, recursive);
        serializer.putKey("textureUUIDs");
        auto state = serializer.arrayBegin();
            foreach(ref texture; textures) {
                uint uuid;
                if (texture !is null) {
                    uuid = texture.getRuntimeUUID();                                    
                } else {
                    uuid = InInvalidUUID;
                }
                serializer.elemBegin;
                serializer.putValue(cast(size_t)uuid);
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
        List of textures this part can use

        TODO: use more than texture 0
    */
    Texture[TextureUsage.COUNT] textures;

    /**
        List of texture IDs
    */
    int[] textureIds;

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
        this(data, textures, inCreateUUID(), parent);
    }

    /**
        Constructs a new part
    */
    this(Node parent = null) {
        super(parent);
        
        version(InDoesRender) glGenBuffers(1, &uvbo);
    }

    /**
        Constructs a new part
    */
    this(MeshData data, Texture[] textures, uint uuid, Node parent = null) {
        super(data, uuid, parent);
        foreach(i; 0..TextureUsage.COUNT) {
            if (i >= textures.length) break;
            this.textures[i] = textures[i];
        }

        version(InDoesRender) {
            glGenBuffers(1, &uvbo);

            mvp = partShader.getUniformLocation("mvp");
            gopacity = partShader.getUniformLocation("opacity");
            
            mmvp = partMaskShader.getUniformLocation("mvp");
            mthreshold = partMaskShader.getUniformLocation("threshold");
        }

        this.updateUVs();
    }
    
    override
    void renderMask(bool dodge = false) {
        
        // Enable writing to stencil buffer and disable writing to color buffer
        glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
        glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
        glStencilFunc(GL_ALWAYS, dodge ? 0 : 1, 0xFF);
        glStencilMask(0xFF);

        // Draw ourselves to the stencil buffer
        drawSelf!true();

        // Disable writing to stencil buffer and enable writing to color buffer
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
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
        this.updateUVs();
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
        version (InDoesRender) {
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
        }
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
            if (Drawable nMask = puppet.find!Drawable(masks[i].maskSrcUUID)) {
                masks[i].maskSrc = nMask;
                validMasks ~= masks[i];
            }
        }

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

}

/**
    Draws a texture at the transform of the specified part
*/
void inDrawTextureAtPart(Texture texture, Part part) {
    const float texWidthP = texture.width()/2;
    const float texHeightP = texture.height()/2;

    // Bind the vertex array
    incDrawableBindVAO();

    partShader.use();
    partShader.setUniform(mvp, 
        inGetCamera().matrix * 
        mat4.translation(vec3(part.transform.matrix() * vec4(1, 1, 1, 1)))
    );
    partShader.setUniform(gopacity, part.opacity);
    partShader.setUniform(gMultColor, part.tint);
    partShader.setUniform(gScreenColor, part.screenTint);
    
    // Bind the texture
    texture.bind();

    // Enable points array
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, sVertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, 4*vec2.sizeof, [
        -texWidthP, -texHeightP,
        texWidthP, -texHeightP,
        -texWidthP, texHeightP,
        texWidthP, texHeightP,
    ].ptr, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

    // Enable UVs array
    glEnableVertexAttribArray(1); // uvs
    glBindBuffer(GL_ARRAY_BUFFER, sUVBuffer);
    glBufferData(GL_ARRAY_BUFFER, 4*vec2.sizeof, [
        0, 0,
        1, 0,
        0, 1,
        1, 1,
    ].ptr, GL_STATIC_DRAW);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

    // Bind element array and draw our mesh
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, sElementBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, 6*ushort.sizeof, (cast(ushort[])[
        0u, 1u, 2u,
        2u, 1u, 3u
    ]).ptr, GL_STATIC_DRAW);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, null);

    // Disable the vertex attribs after use
    glDisableVertexAttribArray(0);
    glDisableVertexAttribArray(1);
}

/**
    Draws a texture at the transform of the specified part
*/
void inDrawTextureAtPosition(Texture texture, vec2 position, float opacity = 1, vec3 color = vec3(1, 1, 1), vec3 screenColor = vec3(0, 0, 0)) {
    const float texWidthP = texture.width()/2;
    const float texHeightP = texture.height()/2;

    // Bind the vertex array
    incDrawableBindVAO();

    partShader.use();
    partShader.setUniform(mvp, 
        inGetCamera().matrix * 
        mat4.scaling(1, 1, 1) * 
        mat4.translation(vec3(position, 0))
    );
    partShader.setUniform(gopacity, opacity);
    partShader.setUniform(gMultColor, color);
    partShader.setUniform(gScreenColor, screenColor);
    
    // Bind the texture
    texture.bind();

    // Enable points array
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, sVertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, 4*vec2.sizeof, [
        -texWidthP, -texHeightP,
        texWidthP, -texHeightP,
        -texWidthP, texHeightP,
        texWidthP, texHeightP,
    ].ptr, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

    // Enable UVs array
    glEnableVertexAttribArray(1); // uvs
    glBindBuffer(GL_ARRAY_BUFFER, sUVBuffer);
    glBufferData(GL_ARRAY_BUFFER, 4*vec2.sizeof, (cast(float[])[
        0, 0,
        1, 0,
        0, 1,
        1, 1,
    ]).ptr, GL_STATIC_DRAW);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

    // Bind element array and draw our mesh
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, sElementBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, 6*ushort.sizeof, (cast(ushort[])[
        0u, 1u, 2u,
        2u, 1u, 3u
    ]).ptr, GL_STATIC_DRAW);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, null);

    // Disable the vertex attribs after use
    glDisableVertexAttribArray(0);
    glDisableVertexAttribArray(1);
}

/**
    Draws a texture at the transform of the specified part
*/
void inDrawTextureAtRect(Texture texture, rect area, rect uvs = rect(0, 0, 1, 1), float opacity = 1, vec3 color = vec3(1, 1, 1), vec3 screenColor = vec3(0, 0, 0), Shader s = null, Camera cam = null) {

    // Bind the vertex array
    incDrawableBindVAO();

    if (!s) s = partShader;
    if (!cam) cam = inGetCamera();
    s.use();
    s.setUniform(s.getUniformLocation("mvp"), 
        cam.matrix * 
        mat4.scaling(1, 1, 1)
    );
    s.setUniform(s.getUniformLocation("opacity"), opacity);
    s.setUniform(s.getUniformLocation("multColor"), color);
    s.setUniform(s.getUniformLocation("screenColor"), screenColor);
    
    // Bind the texture
    texture.bind();

    // Enable points array
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, sVertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, 4*vec2.sizeof, [
        area.left, area.top,
        area.right, area.top,
        area.left, area.bottom,
        area.right, area.bottom,
    ].ptr, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

    // Enable UVs array
    glEnableVertexAttribArray(1); // uvs
    glBindBuffer(GL_ARRAY_BUFFER, sUVBuffer);
    glBufferData(GL_ARRAY_BUFFER, 4*vec2.sizeof, (cast(float[])[
        uvs.x, uvs.y,
        uvs.width, uvs.y,
        uvs.x, uvs.height,
        uvs.width, uvs.height,
    ]).ptr, GL_STATIC_DRAW);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

    // Bind element array and draw our mesh
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, sElementBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, 6*ushort.sizeof, (cast(ushort[])[
        0u, 1u, 2u,
        2u, 1u, 3u
    ]).ptr, GL_STATIC_DRAW);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, null);

    // Disable the vertex attribs after use
    glDisableVertexAttribArray(0);
    glDisableVertexAttribArray(1);
}