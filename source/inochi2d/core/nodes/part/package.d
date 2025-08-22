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
import inochi2d.core.math;
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
        Shader partShaderStage1;
        Shader partShaderStage2;
        Shader partMaskShader;

        /* GLSL Uniforms (Normal) */
        GLint mvpModel;
        GLint mvpViewProjection;
        GLint offset;
        GLint gopacity;
        GLint gMultColor;
        GLint gScreenColor;
        GLint gEmissionStrength;

        
        /* GLSL Uniforms (Stage 1) */
        GLint gs1MvpModel;
        GLint gs1MvpViewProjection;
        GLint gs1offset;
        GLint gs1opacity;
        GLint gs1MultColor;
        GLint gs1ScreenColor;

        
        /* GLSL Uniforms (Stage 2) */
        GLint gs2MvpModel;
        GLint gs2MvpViewProjection;
        GLint gs2offset;
        GLint gs2opacity;
        GLint gs2EmissionStrength;
        GLint gs2MultColor;
        GLint gs2ScreenColor;

        /* GLSL Uniforms (Masks) */
        GLint mMvpModel;
        GLint mMvpViewProjection;
        GLint mthreshold;

        GLuint sVertexBuffer;
        GLuint sUVBuffer;
        GLuint sElementBuffer;
    }

    void inInitPart() {
        inRegisterNodeType!Part;
        partShader = new Shader("part", import("basic/basic.vert"), import("basic/basic.frag"));
        partShaderStage1 = new Shader("part (stage 1)", import("basic/basic.vert"), import("basic/basic-stage1.frag"));
        partShaderStage2 = new Shader("part (stage 2)", import("basic/basic.vert"), import("basic/basic-stage2.frag"));
        partMaskShader = new Shader("part (mask)", import("basic/basic.vert"), import("basic/basic-mask.frag"));

        incDrawableBindVAO();

        partShader.use();
        partShader.setUniform(partShader.getUniformLocation("albedo"), 0);
        partShader.setUniform(partShader.getUniformLocation("emissive"), 1);
        partShader.setUniform(partShader.getUniformLocation("bumpmap"), 2);
        mvpModel = partShader.getUniformLocation("mvpModel");
        mvpViewProjection = partShader.getUniformLocation("mvpViewProjection");
        offset = partShader.getUniformLocation("offset");
        gopacity = partShader.getUniformLocation("opacity");
        gMultColor = partShader.getUniformLocation("multColor");
        gScreenColor = partShader.getUniformLocation("screenColor");
        gEmissionStrength = partShader.getUniformLocation("emissionStrength");
        
        partShaderStage1.use();
        partShaderStage1.setUniform(partShader.getUniformLocation("albedo"), 0);
        gs1MvpModel = partShaderStage1.getUniformLocation("mvpModel");
        gs1MvpViewProjection = partShaderStage1.getUniformLocation("mvpViewProjection");
        gs1offset = partShaderStage1.getUniformLocation("offset");
        gs1opacity = partShaderStage1.getUniformLocation("opacity");
        gs1MultColor = partShaderStage1.getUniformLocation("multColor");
        gs1ScreenColor = partShaderStage1.getUniformLocation("screenColor");

        partShaderStage2.use();
        partShaderStage2.setUniform(partShaderStage2.getUniformLocation("emissive"), 1);
        partShaderStage2.setUniform(partShaderStage2.getUniformLocation("bumpmap"), 2);
        gs2MvpModel = partShaderStage1.getUniformLocation("mvpModel");
        gs2MvpViewProjection = partShaderStage1.getUniformLocation("mvpViewProjection");
        gs2offset = partShaderStage2.getUniformLocation("offset");
        gs2opacity = partShaderStage2.getUniformLocation("opacity");
        gs2MultColor = partShaderStage2.getUniformLocation("multColor");
        gs2ScreenColor = partShaderStage2.getUniformLocation("screenColor");
        gs2EmissionStrength = partShaderStage2.getUniformLocation("emissionStrength");

        partMaskShader.use();
        partMaskShader.setUniform(partMaskShader.getUniformLocation("albedo"), 0);
        partMaskShader.setUniform(partMaskShader.getUniformLocation("emissive"), 1);
        partMaskShader.setUniform(partMaskShader.getUniformLocation("bumpmap"), 2);
        mMvpModel = partMaskShader.getUniformLocation("mvpModel");
        mMvpViewProjection = partMaskShader.getUniformLocation("mvpViewProjection");
        mthreshold = partMaskShader.getUniformLocation("threshold");
        
        glGenBuffers(1, &sVertexBuffer);
        glGenBuffers(1, &sUVBuffer);
        glGenBuffers(1, &sElementBuffer);
        
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
        glBindBuffer(GL_ARRAY_BUFFER, uvbo);
        glBufferData(GL_ARRAY_BUFFER, data.uvs.length*vec2.sizeof, data.uvs.ptr, GL_STATIC_DRAW);
    }

    void setupShaderStage(int stage, mat4 matrix) {
                
        vec3 clampedTint = tint;
        if (!offsetTint.x.isNaN) clampedTint.x = clamp(tint.x*offsetTint.x, 0, 1);
        if (!offsetTint.y.isNaN) clampedTint.y = clamp(tint.y*offsetTint.y, 0, 1);
        if (!offsetTint.z.isNaN) clampedTint.z = clamp(tint.z*offsetTint.z, 0, 1);

        vec3 clampedScreen = screenTint;
        if (!offsetScreenTint.x.isNaN) clampedScreen.x = clamp(screenTint.x+offsetScreenTint.x, 0, 1);
        if (!offsetScreenTint.y.isNaN) clampedScreen.y = clamp(screenTint.y+offsetScreenTint.y, 0, 1);
        if (!offsetScreenTint.z.isNaN) clampedScreen.z = clamp(screenTint.z+offsetScreenTint.z, 0, 1);

        mat4 mModel = puppet.transform.matrix * matrix;
        mat4 mViewProjection = inGetCamera().matrix;
        
        switch(stage) {
            case 0:
                // STAGE 1 - Advanced blending

                glDrawBuffers(1, [GL_COLOR_ATTACHMENT0].ptr);

                partShaderStage1.use();
                partShaderStage1.setUniform(gs1offset, data.origin);
                partShaderStage1.setUniform(gs1MvpModel, mModel);
                partShaderStage1.setUniform(gs1MvpViewProjection, mViewProjection);
                partShaderStage1.setUniform(gs1opacity, clamp(offsetOpacity * opacity, 0, 1));

                partShaderStage1.setUniform(partShaderStage1.getUniformLocation("albedo"), 0);
                partShaderStage1.setUniform(gs1MultColor, clampedTint);
                partShaderStage1.setUniform(gs1ScreenColor, clampedScreen);
                inSetBlendMode(blendingMode, false);
                break;
            case 1:

                // STAGE 2 - Basic blending (albedo, bump)
                glDrawBuffers(2, [GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);

                partShaderStage2.use();
                partShaderStage2.setUniform(gs2offset, data.origin);
                partShaderStage2.setUniform(gs2MvpModel, mModel);
                partShaderStage2.setUniform(gs2MvpViewProjection, mViewProjection);
                partShaderStage2.setUniform(gs2opacity, clamp(offsetOpacity * opacity, 0, 1));
                partShaderStage2.setUniform(gs2EmissionStrength, emissionStrength*offsetEmissionStrength);

                partShaderStage2.setUniform(partShaderStage2.getUniformLocation("emission"), 0);
                partShaderStage2.setUniform(partShaderStage2.getUniformLocation("bump"), 1);

                // These can be reused from stage 2
                partShaderStage1.setUniform(gs2MultColor, clampedTint);
                partShaderStage1.setUniform(gs2ScreenColor, clampedScreen);
                inSetBlendMode(blendingMode, true);
                break;
            case 2:

                // Basic blending
                glDrawBuffers(3, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);

                partShader.use();
                partShader.setUniform(offset, data.origin);
                partShader.setUniform(mvpModel, mModel);
                partShader.setUniform(mvpViewProjection, mViewProjection);
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
                inSetBlendMode(blendingMode, true);
                break;
            default: return;
        }

    }

    void renderStage(bool advanced=true)(BlendMode mode) {

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

        static if (advanced) {
            // Blending barrier
            inBlendModeBarrier(mode);
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

        // Calculate matrix
        mat4 matrix = transform.matrix();
        if (overrideTransformMatrix !is null)
            matrix = overrideTransformMatrix.matrix;
        if (oneTimeTransform !is null)
            matrix = (*oneTimeTransform) * matrix;

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

        static if (isMask) {
            
            mat4 mModel = puppet.transform.matrix * matrix;
            mat4 mViewProjection = inGetCamera().matrix;

            partMaskShader.use();
            partMaskShader.setUniform(offset, data.origin);
            partMaskShader.setUniform(mMvpModel, mModel);
            partMaskShader.setUniform(mMvpViewProjection, mViewProjection);
            partMaskShader.setUniform(mthreshold, clamp(offsetMaskThreshold + maskAlphaThreshold, 0, 1));

            // Make sure the equation is correct
            glBlendEquation(GL_FUNC_ADD);
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

            renderStage!false(blendingMode);
        } else {

            bool hasEmissionOrBumpmap = (textures[1] || textures[2]);

            if (inUseMultistageBlending(blendingMode)) {

                // TODO: Detect if this Part is NOT in a composite,
                // If so, we can relatively safely assume that we may skip stage 1.
                setupShaderStage(0, matrix);
                renderStage(blendingMode);
                
                // Only do stage 2 if we have emission or bumpmap textures.
                if (hasEmissionOrBumpmap) {
                    setupShaderStage(1, matrix);
                    renderStage!false(blendingMode);
                }
            } else {
                setupShaderStage(2, matrix);
                renderStage!false(blendingMode);
            }
        }

        // Reset draw buffers
        glDrawBuffers(3, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);
        glBlendEquation(GL_FUNC_ADD);
    }

protected:

    override
    string typeId() { return "Part"; }

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void serializeSelfImpl(ref JSONValue object, bool recursive = true) {
        super.serializeSelfImpl(object, recursive);

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
            size_t i = 0;
            foreach(ref JSONValue element; object["textures"].array) {

                // uint max = no texture set
                uint textureId = element.tryGet!uint(NO_TEXTURE);
                if (textureId == NO_TEXTURE) continue;

                textureIds ~= textureId;
                this.textures[i++] = inGetTextureFromId(textureId);
            }
        }
        
        object.tryGetRef(opacity, "opacity");
        object.tryGetRef(maskAlphaThreshold, "mask_threshold");
        object.tryGetRef(tint, "tint");
        object.tryGetRef(screenTint, "screenTint");
        object.tryGetRef(tint, "tint");
        object.tryGetRef(emissionStrength, "emissionStrength");
        object.tryGetRef(blendingMode, "blend_mode");
        object.tryGetRef(masks, "masks");

        if (object.isJsonArray("masked_by")) {

            // Go to every masked part
            MaskingMode mode = object.tryGet!MaskingMode("mask_mode");
            foreach(imask; object["masked_by"].array) {
                uint uuid = imask.tryGet!uint();
                this.masks ~= MaskBinding(uuid, mode, null);
            }
        }

        // Update indices and vertices
        this.updateUVs();
    }

    override
    void serializePartial(ref JSONValue object, bool recursive=true) {
        super.serializePartial(object, recursive);

        object["textureUUIDs"] = JSONValue.emptyArray;
        foreach(ref texture; textures) {
            uint uuid = texture !is null ? 
                texture.getRuntimeUUID() : 
                InInvalidUUID;

            object["textureUUIDs"] ~= JSONValue(uuid);
        }
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
        
        glGenBuffers(1, &uvbo);
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

        glGenBuffers(1, &uvbo);

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
        if (!enabled) return;
        if (!data.isReady) return; // Yeah, don't even try
        
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
    partShader.setUniform(mvpModel, 
        mat4.translation(vec3(part.transform.matrix() * vec4(1, 1, 1, 1)))
    );
    partShader.setUniform(mvpViewProjection, 
        inGetCamera().matrix
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
    partShader.setUniform(mvpModel, 
        mat4.scaling(1, 1, 1) * 
        mat4.translation(vec3(position, 0))
    );
    partShader.setUniform(mvpViewProjection, 
        inGetCamera().matrix
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