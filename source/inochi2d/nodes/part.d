/**
    Inochi2D Part

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.nodes.part;
import inochi2d.nodes.visual;
import inochi2d.effect;
import inochi2d.nodes;
import inochi2d.core;
import numath;
import nulib;
import numem;

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
@nogc:
    Mesh mesh_;
    DeformedMesh deformed_;
    DeformedMesh base_;
    weak_vector!MeshEffect effects_;

    //
    //      PARAMETER OFFSETS
    //
    float offsetMaskThreshold = 0;
    float offsetOpacity = 1;
    float offsetEmissionStrength = 1;
    vec3 offsetTint = vec3(0);
    vec3 offsetScreenTint = vec3(0);

protected:

    /**
        The deformed mesh state of the part.
    */
    @property ref DeformedMesh deformedMesh() => deformed_;

    /**
        The current active draw list slot for this
        drawable.
    */
    DrawListAlloc* drawListSlot;

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
            recursive = Whether to recurse through children.
    */
    override
    void onSerialize(ref DataNode object, bool recursive = true) {
        super.onSerialize(object, recursive);

        MeshData data = MeshData(mesh_);
        object["mesh"] = data.serialize();
        object["textures"] = DataNode.createArray();
        foreach (ref texture; textures) {
            if (texture) {
                ptrdiff_t index = puppet.getTextureSlotIndexFor(texture);
                object["textures"].array ~= DataNode(index >= 0 ? index : NO_TEXTURE);
            } else {
                object["textures"].array ~= DataNode(NO_TEXTURE);
            }
        }
        
        // Serialize attached effects.
        if (effects_.length > 0) {
            object["effects"] = DataNode.createArray();
            foreach(effect; effects_) {

                DataNode effectObj;
                effect.serialize(effectObj);
                object["effects"].array ~= effectObj;
            }
        }

        // Serialize basic data.
        object["blend_mode"] = cast(uint)blendingMode;
        object["tint"] = tint.serialize();
        object["screenTint"] = screenTint.serialize();
        object["emissionStrength"] = emissionStrength;
        object["masks"] = masks.serialize();
        object["opacity"] = opacity;
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object = The DataNode to deserialize from.
    */
    override
    void onDeserialize(ref DataNode object) {
        super.onDeserialize(object);

        this.deformed_ = nogc_new!DeformedMesh();
        this.base_ = nogc_new!DeformedMesh();
        this.mesh = Mesh.fromMeshData(object.tryGet!MeshData("mesh"));

        // Textures
        if ("textures" in object && object["textures"].isArray) {
            foreach (i, ref DataNode element; object["textures"].array) {

                uint textureId = element.tryGet!uint(NO_TEXTURE);
                if (textureId == NO_TEXTURE)
                    continue;

                // TODO: Abstract this to properly handle refcounts.
                this.textures[i] = puppet.textureCache.get(textureId);
                if (this.textures[i])
                    this.textures[i].retain();
            }
        }

        // Effects
        if ("effects" in object && object["effects"].isArray) {
            foreach(i, ref DataNode element; object["effects"].array) {
                if (MeshEffect effect = in_effect_registry.tryCreateFrom(element, this)) {
                    effect.deserialize(element);
                }
            }
        }

        object.tryGetRef(opacity, "opacity");
        object.tryGetRef(tint, "tint");
        object.tryGetRef(screenTint, "screenTint");
        object.tryGetRef(emissionStrength, "emissionStrength");

        if ("blend_mode" in object && object["blend_mode"].isNumber)
            blendingMode = cast(BlendMode)object.tryGet!uint("blend_mode", blendingMode.normal);
        else
            blendingMode = object.tryGet!string("blend_mode", "Normal").toBlendMode();
    }

    /**
        Called when the node is to finalize its deserialization from disk.
    */
    override
    void onFinalize() {
        super.onFinalize();
        foreach(effect; effects_) {
            effect.finalize();
        }
    }

    /**
        Called during the early update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onPreUpdate(DrawList drawList) {
        offsetMaskThreshold = 0;
        offsetOpacity = 1;
        offsetTint = vec3(1, 1, 1);
        offsetScreenTint = vec3(0, 0, 0);
        offsetEmissionStrength = 1;

        super.onPreUpdate(drawList);
        this.resetDeform();
    }

    /**
        Called during the update phase of a new frame.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
    */
    override
    void onUpdate(float delta, DrawList drawList) {
        super.onUpdate(delta, drawList);
        deformed_.pushMatrix(transform.matrix);
    }

    /**
        Called during the late update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onPostUpdate(DrawList drawList) {
        super.onPostUpdate(drawList);
        this.drawListSlot = drawList.allocate(deformed_.vertices, deformed_.indices);

        // Apply mesh effects.
        foreach(effect; effects_)
            effect.apply(drawList);
    }

    /**
        Called when the node is to be redrawn.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
            mode =      The masking mode to draw with.
    */
    override
    void onDraw(float delta, DrawList drawList, MaskingMode mode) {
        if (mode >= MaskingMode.mask) {
            drawList.setMesh(drawListSlot);
            drawList.setDrawState(DrawState.defineMask);
            drawList.setSources(textures);
            drawList.setMasking(mode);
            drawList.next();
            return;
        }

        if (!this.enabled)
            return;

        PartVars vars = PartVars(
                tint * offsetTint,
                screenTint * offsetScreenTint,
                opacity * offsetOpacity,
                emissionStrength * offsetEmissionStrength
        );

        if (masks.length > 0) {
            foreach (ref mask; masks) {
                if (mask.maskSrc)
                    mask.maskSrc.onDraw(delta, drawList, mask.mode);
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
        Mesh effects applied to the part.
    */
    final @property MeshEffect[] effects() => effects_;

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
        foreach (texture; textures) {
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
        this(data, guid, parent);
        foreach (i; 0 .. TextureUsage.COUNT) {
            if (i >= textures.length)
                break;
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

    /**
        Applies an offset to the Node's transform.

        Params:
            other = The transform to offset the current global transform by.
    */
    override
    void offsetTransform(Transform other) @nogc {
        super.offsetTransform(other);
    }

    /**
        Adds a mesh effect to the part.

        Param:
            T =     The type of the mesh effect to add.
            args =  The arguments to pass to the effect's constructor.
    */
    void addEffect(T, Args...)(Args args)
    if (is(T : MeshEffect)) {
        this.effects_ ~= nogc_new!T(this, args);
    }

    /**
        Removes a given mesh effect from this part.

        Params:
            effect = The effect to remove.
    */
    void removeEffect(MeshEffect effect) {
        foreach(i, applied; effects_) {
            if (applied is effect) {
                this.effects_.removeAt(i);
                effect.release();
                return;
            }
        }
    }

    /**
        Gets whether a property with the given name exists
        in the object.

        Params:
            key = The name of the property.
        
        Returns:
            $(D true) if the property exists,
            $(D false) otherwise.
    */
    override
    bool hasProperty(string key) const {
        switch (key) {
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
            return super.hasProperty(key);
        }
    }

    /**
        Gets the value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The floating point value of the property.
    */
    override
    float getProperty(string key) const {
        switch (key) {
        case "opacity":
            return offsetOpacity;
        case "tint.r":
            return offsetTint.x;
        case "tint.g":
            return offsetTint.y;
        case "tint.b":
            return offsetTint.z;
        case "screenTint.r":
            return offsetScreenTint.x;
        case "screenTint.g":
            return offsetScreenTint.y;
        case "screenTint.b":
            return offsetScreenTint.z;
        case "emissionStrength":
            return offsetEmissionStrength;
        default:
            return super.getProperty(key);
        }
    }

    /**
        Gets the default value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The default value of the property.
    */
    override
    float getPropertyDefault(string key) const {
        switch (key) {
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
        default:
            return super.getPropertyDefault(key);
        }
    }

    /**
        Sets the value of the property.

        Params:
            key =   The name of the property.
            value = The value to set the property to.
    */
    override
    void setProperty(string key, float value) {
        switch (key) {
        case "opacity":
            offsetOpacity *= value;
            return;
        case "tint.r":
            offsetTint.x *= value;
            return;
        case "tint.g":
            offsetTint.y *= value;
            return;
        case "tint.b":
            offsetTint.z *= value;
            return;
        case "screenTint.r":
            offsetScreenTint.x += value;
            return;
        case "screenTint.g":
            offsetScreenTint.y += value;
            return;
        case "screenTint.b":
            offsetScreenTint.z += value;
            return;
        case "emissionStrength":
            offsetEmissionStrength += value;
            return;
        default:
            return super.setProperty(key, value);
        }
    }
}

mixin Register!(Part, in_node_registry);
