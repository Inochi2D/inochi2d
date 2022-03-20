/*
    Inochi2D Part

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.part;
import inochi2d.fmt;
import inochi2d.core.nodes.drawable;
import inochi2d.core;
import inochi2d.math;
import bindbc.opengl;
import std.exception;
import std.algorithm.mutation : copy;

public import inochi2d.core.meshdata;


package(inochi2d) {
    private {
        Shader partShader;
        Shader partMaskShader;

        /* GLSL Uniforms (Normal) */
        GLint mvp;
        GLint gopacity;
        GLint gtint;

        /* GLSL Uniforms (Masks) */
        GLint mmvp;
        GLint mthreshold;
        GLint mgopacity;

        GLuint sVertexBuffer;
        GLuint sUVBuffer;
        GLuint sElementBuffer;
    }

    void inInitPart() {
        inRegisterNodeType!Part;
        partShader = new Shader(import("basic/basic.vert"), import("basic/basic.frag"));
        partMaskShader = new Shader(import("basic/basic.vert"), import("basic/basic-mask.frag"));

        mvp = partShader.getUniformLocation("mvp");
        gopacity = partShader.getUniformLocation("opacity");
        gtint = partShader.getUniformLocation("tint");
        
        mmvp = partMaskShader.getUniformLocation("mvp");
        mthreshold = partMaskShader.getUniformLocation("threshold");
        mgopacity = partMaskShader.getUniformLocation("opacity");
        
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
    vec2(0, 0),
    vec2(1, 1),
	[
		0, 1, 2,
		2, 1, 3
	]);
	Part p = new Part(data, [tex], parent);
	p.name = name;
    return p;
}

/**
    Masking mode
*/
enum MaskingMode {

    /**
        The part should be masked by the drawables specified
    */
    Mask,

    /**
        The path should be dodge masked by the drawables specified
    */
    DodgeMask
}

/**
    Blending modes

    TODO: Implement advanced blending system
*/
enum BlendMode {
    // Normal blending mode
    Normal,

    // Multiply blending mode
    Multiply,
    
    // Color Dodge
    ColorDodge,

    // Linear Dodge
    LinearDodge,

    // Screen
    Screen
}

/**
    Dynamic Mesh Part
*/
@TypeId("Part")
class Part : Drawable {
private:
    
    GLuint uvbo;

    uint[] pendingMasks;

    void updateUVs() {
        glBindBuffer(GL_ARRAY_BUFFER, uvbo);
        glBufferData(GL_ARRAY_BUFFER, data.uvs.length*vec2.sizeof, data.uvs.ptr, GL_STATIC_DRAW);
    }

    /*
        RENDERING
    */

    void drawSelf(bool isMask = false)() {

        // In some cases this may happen
        if (textures.length == 0) return;

        // Bind the vertex array
        incDrawableBindVAO();

        static if (isMask) {
            partMaskShader.use();
            partMaskShader.setUniform(mmvp, inGetCamera().matrix * transform.matrix());
            partMaskShader.setUniform(mthreshold, maskAlphaThreshold);
            partMaskShader.setUniform(mgopacity, opacity);
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        } else {
            partShader.use();
            partShader.setUniform(mvp, inGetCamera().matrix * transform.matrix());
            partShader.setUniform(gopacity, opacity);
            partShader.setUniform(gtint, tint);

            // COMPAT MODE
            switch(blendingMode) {
                case BlendMode.Normal: 
                    glBlendEquation(GL_FUNC_ADD);
                    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;
                case BlendMode.Multiply: 
                    glBlendEquation(GL_FUNC_ADD);
                    glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA); break;
                case BlendMode.ColorDodge:
                    glBlendEquation(GL_FUNC_ADD);
                    glBlendFunc(GL_DST_COLOR, GL_ONE); break;
                case BlendMode.LinearDodge:
                    glBlendEquation(GL_FUNC_ADD);
                    glBlendFunc(GL_ONE, GL_ONE); break;
                case BlendMode.Screen:
                    glBlendEquation(GL_FUNC_ADD);
                    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR); break;
                default: assert(0);
            }

            // TODO: EXT MODE
        }

        // Bind the texture
        textures[0].bind();

        // Enable points array
        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Enable UVs array
        glEnableVertexAttribArray(1); // uvs
        glBindBuffer(GL_ARRAY_BUFFER, uvbo);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Bind index buffer
        this.bindIndex();

        // Disable the vertex attribs after use
        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
    }

protected:
    override
    void renderMask() {
        
        // Enable writing to stencil buffer and disable writing to color buffer
        glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
        glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
        glStencilFunc(GL_ALWAYS, 1, 0xFF);
        glStencilMask(0xFF);

        // Draw ourselves to the stencil buffer
        drawSelf!true();

        // Disable writing to stencil buffer and enable writing to color buffer
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    }

    override
    string typeId() { return "Part"; }

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void serializeSelf(ref InochiSerializer serializer) {
        super.serializeSelf(serializer);
        
        if (inIsINPMode()) {
            serializer.putKey("textures");
            auto state = serializer.arrayBegin();
                foreach(texture; textures) {
                    ptrdiff_t index = puppet.getTextureSlotIndexFor(texture);
                    if (index >= 0) {
                        serializer.elemBegin;
                        serializer.putValue(cast(size_t)index);
                    }
                }
            serializer.arrayEnd(state);
        } else {
            serializer.putKey("textures");
            auto state = serializer.arrayBegin();
                serializer.elemBegin;
                serializer.putValue(name);
            serializer.arrayEnd(state);
        }

        serializer.putKey("blend_mode");
        serializer.serializeValue(blendingMode);
        
        serializer.putKey("tint");
        tint.serialize(serializer);

        serializer.putKey("mask_mode");
        serializer.serializeValue(maskingMode);

        if (mask.length > 0) {

            serializer.putKey("masked_by");
            auto state = serializer.arrayBegin();
                foreach(m; mask) {
                    serializer.elemBegin;
                    serializer.putValue(m.uuid);
                }
            serializer.arrayEnd(state);
        }

        serializer.putKey("mask_threshold");
        serializer.putValue(maskAlphaThreshold);

        serializer.putKey("opacity");
        serializer.putValue(opacity);
    }

    /**
        Allows serializing self data (with compact serializer)
    */
    override
    void serializeSelf(ref InochiSerializerCompact serializer) {
        super.serializeSelf(serializer);
        
        if (inIsINPMode()) {
            serializer.putKey("textures");
            auto state = serializer.arrayBegin();
                foreach(texture; textures) {
                    ptrdiff_t index = puppet.getTextureSlotIndexFor(texture);
                    if (index >= 0) {
                        serializer.elemBegin;
                        serializer.putValue(cast(size_t)index);
                    }
                }
            serializer.arrayEnd(state);
        } else {
            serializer.putKey("textures");
            auto state = serializer.arrayBegin();
                serializer.elemBegin;
                serializer.putValue(name);
            serializer.arrayEnd(state);
        }

        serializer.putKey("blend_mode");
        serializer.serializeValue(blendingMode);

        serializer.putKey("tint");
        tint.serialize(serializer);

        serializer.putKey("mask_mode");
        serializer.serializeValue(maskingMode);

        if (mask.length > 0) {

            serializer.putKey("masked_by");
            auto state = serializer.arrayBegin();
                foreach(m; mask) {
                    serializer.elemBegin;
                    serializer.putValue(m.uuid);
                }
            serializer.arrayEnd(state);
        }

        serializer.putKey("mask_threshold");
        serializer.putValue(maskAlphaThreshold);

        serializer.putKey("opacity");
        serializer.putValue(opacity);

    }

    override
    SerdeException deserializeFromAsdf(Asdf data) {
        super.deserializeFromAsdf(data);

    
        
        if (inIsINPMode()) {

            foreach(texElement; data["textures"].byElement) {
                uint textureId;
                texElement.deserializeValue(textureId);
                this.textures ~= inGetTextureFromId(textureId);
            }
        } else {

            // TODO: Index textures by ID
            string texName;
            auto elements = data["textures"].byElement;
            if (!elements.empty) {
                if (auto exc = elements.front.deserializeValue(texName)) return exc;
                this.textures = [new Texture(texName)];
            }
        }

        data["opacity"].deserializeValue(this.opacity);
        data["mask_threshold"].deserializeValue(this.maskAlphaThreshold);

        // Older models may not have tint
        if (!data["tint"].isEmpty) deserialize(tint, data["tint"]);

        // Older models may not have blend mode
        if (!data["blend_mode"].isEmpty) data["blend_mode"].deserializeValue(this.blendingMode);

        if (!data["masked_by"].isEmpty) {
            data["mask_mode"].deserializeValue(this.maskingMode);

            // Go every masked part
            foreach(imask; data["masked_by"].byElement) {
                uint uuid;
                if (auto exc = imask.deserializeValue(uuid)) return exc;
                this.pendingMasks ~= uuid;
            }
        }

        // Update indices and vertices
        this.updateUVs();
        return null;
    }

public:
    /**
        List of textures this part can use

        TODO: use more than texture 0
    */
    Texture[] textures;

    /**
        A part this part should "dodge"
    */
    Drawable[] mask;

    /**
        Masking mode
    */
    MaskingMode maskingMode = MaskingMode.Mask;

    /**
        Blending mode
    */
    BlendMode blendingMode = BlendMode.Normal;
    
    /**
        Alpha Threshold for the masking system, the higher the more opaque pixels will be discarded in the masking process
    */
    float maskAlphaThreshold = 0.01;

    /**
        Opacity of the mesh
    */
    float opacity = 1;

    /**
        Tint of color based texture
    */
    vec3 tint = vec3(1, 1, 1);

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
        this.textures = textures;
        glGenBuffers(1, &uvbo);

        mvp = partShader.getUniformLocation("mvp");
        gopacity = partShader.getUniformLocation("opacity");
        
        mmvp = partMaskShader.getUniformLocation("mvp");
        mthreshold = partMaskShader.getUniformLocation("threshold");
        mgopacity = partMaskShader.getUniformLocation("opacity");
        this.updateUVs();
    }
    
    override
    void rebuffer(MeshData data) {
        super.rebuffer(data);
        this.updateUVs();
    }

    override
    void drawOne() {
        if (!enabled) return;
        if (opacity == 0) return; // Might as well save the trouble
        if (!data.isReady) return; // Yeah, don't even try
        
        glUniform1f(mthreshold, maskAlphaThreshold);
        glUniform1f(mgopacity, opacity);
        
        if (mask.length > 0) {
            inBeginMask();

            foreach(drawable; mask) {
                drawable.renderMask();
            }

            // Begin drawing content
            if (maskingMode == MaskingMode.Mask) inBeginMaskContent();
            else inBeginDodgeContent();
            
            // We are the content
            this.drawSelf();

            inEndMask();
            return;
        }

        this.drawSelf();
        super.drawOne();
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
    void finalize() {
        super.finalize();
        foreach(pmask; pendingMasks) {
            if (Node nMask = puppet.find!Drawable(pmask)) {
                mask ~= cast(Drawable)nMask;
            }
        }
        pendingMasks.length = 0;
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
    partShader.setUniform(gtint, part.tint);
    
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
void inDrawTextureAtPosition(Texture texture, vec2 position, float opacity = 1, vec3 color = vec3(1, 1, 1)) {
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
    partShader.setUniform(gtint, color);
    
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