/**
    Inochi2D Part Node

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.nodes.visual.part;
import inochi2d.nodes.visual;
import inochi2d.common;
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
    vec3 tint;
    vec3 screenTint;
    private void[4] __dummy;
    float opacity;
    float emissionStrength;
}

/**
    Dynamic Mesh Part
*/
@TypeId("Part", IN_MAKE_TAG!(1, 1))
class Part : Visual, IDeformable {
private:
@nogc:
    Mesh mesh_;
    DeformedMesh deformed_;
    DeformedMesh base_;
    weak_vector!MeshEffect effects_;

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
    */
    override
    void onSerialize(ref DataNode object) {
        super.onSerialize(object);

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
        object["opacity"] = opacity;
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object =    The DataNode to deserialize from.
            state =     The state of the deserializer.
    */
    override
    void onDeserialize(ref DataNode object, ref ModelState state) {
        super.onDeserialize(object, state);

        auto meshData = object.tryGet!MeshData(state, "mesh");
        this.deformed_ = nogc_new!DeformedMesh();
        this.base_ = nogc_new!DeformedMesh();
        this.mesh = Mesh.fromMeshData(meshData);

        // Textures
        if ("textures" in object && object["textures"].isArray) {
            foreach (i, ref DataNode element; object["textures"].array) {

                uint textureId = element.tryGet!uint(state, NO_TEXTURE);
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
            foreach(i, ref element; object["effects"].array) {
                if (MeshEffect effect = in_effect_registry.tryCreateFrom(element, this)) {
                    effect.deserialize(element, state);
                }
            }
        }

        object.tryGetRef(state, opacity, "opacity", 1);
        object.tryGetRef(state, tint.data, "tint");
        object.tryGetRef(state, screenTint.data, "screenTint");
        object.tryGetRef(state, emissionStrength, "emissionStrength");

        if ("blend_mode" in object && object["blend_mode"].isNumber)
            blendingMode = cast(BlendMode)object.tryGet!uint(state, "blend_mode", blendingMode.normal);
        else
            blendingMode = object.tryGet!string(state, "blend_mode", "Normal").toBlendMode();
    }

    /**
        Called when the node is to finalize its deserialization from disk.

        Params:
            state =     The state of the deserializer.
    */
    override
    void onFinalize(ref ModelState state) {
        super.onFinalize(state);
        foreach(effect; effects_) {
            effect.finalize(state);
        }
    }

    /**
        Called during the early update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onPreUpdate(DrawList drawList) {
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
        deformed_.pushMatrix(this.deformMatrix);
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
    */
    override
    void onDraw(float delta, DrawList drawList) {
        if (!this.enabled)
            return;

        PartVars vars = PartVars(
            tint: tint * props.get!vec3(PROP_TINT_RGB),
            screenTint: screenTint * props.get!vec3(PROP_SCREEN_RGB),
            opacity: opacity * props.get!float(PROP_OPACITY),
            emissionStrength: emissionStrength * props.get!float(PROP_EMISSION_STRENGTH)
        );

        drawList.setMesh(drawListSlot);
        drawList.setVariables!PartVars(nid, vars);
        drawList.setBlending(blendingMode);
        drawList.setSources(textures);
        drawList.next();
    }

    /**
        Called when the node should be drawn to a mask.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
            mode =      The masking mode to draw with.
    */
    override
    void onDrawMask(float delta, DrawList drawList, MaskingMode mode) {
        drawList.setMesh(drawListSlot);
        drawList.setSources(textures);
        drawList.setMasking(mode);
        drawList.next();
    }

    /**
        Called when the node is to define its properties.

        Call $(D propList.define) with a quark to do this.

        Params:
            propList = The property list to populate.
    */
    override
    void onDefineProperties(ref PropertyStore propList) {
        super.onDefineProperties(propList);
        
        propList.define!float(PROP_SCREEN_R,          0);
        propList.define!float(PROP_SCREEN_G,          0);
        propList.define!float(PROP_SCREEN_B,          0);
        propList.define!float(PROP_TINT_R,            1);
        propList.define!float(PROP_TINT_G,            1);
        propList.define!float(PROP_TINT_B,            1);
        propList.define!float(PROP_OPACITY,           1);
        propList.define!float(PROP_EMISSION_STRENGTH, 1);

        // Define combined overlays.
        propList.defineOverlay!vec3(PROP_SCREEN_RGB, propList.offsetOf(PROP_SCREEN_R));
        propList.defineOverlay!vec3(PROP_TINT_RGB,   propList.offsetOf(PROP_TINT_R));
    }

public:

    /**
        Whether the node can be used as a source of masking operations.
    */
    override @property bool isMasking() @nogc nothrow pure => true;

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
        The base matrix of the object before any parameters have been applied.
    */
    override @property Basis deformBaseMatrix() @nogc => baseMatrix;

    /**
        World matrix of the deformable object.
    */
    override @property Basis deformMatrix() @nogc => matrix;

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
        nogc_delete(base_);
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
        base_.pushMatrix(this.deformBaseMatrix);
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
    override
    void deform(size_t offset, vec2 deform, bool absolute = false) {
        deformed_.deform(offset, deform);
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
}
mixin Register!(Part, in_node_registry);
