/**
    Inochi2D Composite Node

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.nodes.visual.composite;
import inochi2d.nodes.visual;
import inochi2d.common;
import inochi2d.nodes;
import inochi2d.core;
import numem;
import nulib;

public import inochi2d.core.render.state;

struct CompositeVars {
    vec3 tint;
    vec3 screenTint;
    private void[4] __dummy0;
    float opacity;
}

/**
    Composite Node
*/
@TypeId("Composite", IN_MAKE_TAG!(3, 1))
class Composite : Visual {
private:
@nogc:
    DrawListAlloc* ssDrawList_;
    weak_vector!Visual visuals_;

protected:

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
    */
    override
    void onSerialize(ref DataNode object) {
        super.onSerialize(object);
        object["blend_mode"] = cast(uint)blendingMode;
        object["tint"] = tint.serialize();
        object["screenTint"] = screenTint.serialize();
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

        object.tryGetRef(state, opacity, "opacity");
        object.tryGetRef(state, tint, "tint");
        object.tryGetRef(state, screenTint, "screenTint");

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
        this.notifyVisualsChanged();
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

        propList.define!float(PROP_SCREEN_R, 0);
        propList.define!float(PROP_SCREEN_G, 0);
        propList.define!float(PROP_SCREEN_B, 0);
        propList.define!float(PROP_TINT_R, 1);
        propList.define!float(PROP_TINT_G, 1);
        propList.define!float(PROP_TINT_B, 1);
        propList.define!float(PROP_OPACITY, 1);

        // Define combined overlays.
        propList.defineOverlay!vec3(PROP_SCREEN_RGB, propList.offsetOf(PROP_SCREEN_R));
        propList.defineOverlay!vec3(PROP_TINT_RGB, propList.offsetOf(PROP_TINT_R));
    }

    /**
        Called during the early update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onPreUpdate(DrawList drawList) {
        super.onPreUpdate(drawList);
        ssDrawList_ = null;
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

        // Avoid over allocating a single screenspace
        // rect.
        if (!ssDrawList_)
            ssDrawList_ = drawList.allocate(__screenSpaceMesh.vertices, __screenSpaceMesh.indices);
    }

    /**
        Called when the node is to be redrawn.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
    */
    override
    void onDraw(float delta, DrawList drawList) {
        if (visuals_.length == 0)
            return;

        CompositeVars compositeVars = CompositeVars(
                tint: tint * props.get!vec3(PROP_TINT_RGB),
                screenTint: screenTint * props.get!vec3(PROP_SCREEN_RGB),
                opacity: opacity * props.get!float(PROP_OPACITY)
        );

        visuals_.sortNodes();

        // Push sub render area.
        drawList.beginComposite();
        foreach (ref visual; visuals_) {
            visual.draw(delta, drawList);
        }
        drawList.endComposite();

        // Then blit it to the main framebuffer
        drawList.setVariables!CompositeVars(nid, compositeVars);
        drawList.setMesh(ssDrawList_);
        drawList.setBlending(blendingMode);
        drawList.blit();
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
        visuals_.sortNodes();
        foreach (ref visual; visuals_) {
            if (visual.isMasking)
                visual.drawMask(delta, drawList, mode);
        }
    }

    /**
        Requests that the list gather sub-visuals to be rendered, if applicable.

        Params:
            visuals =           The list to write to, the list may be resized by the
                                implementation.
            recurseDelegates =  Whether to recurse through delegate visuals.
            append =            Whether to append to the visuals list.
    */
    override
    void onDelegateFindVisuals(ref weak_vector!Visual visuals, bool recurseDelegates, bool append) {
        this.notifyVisualsChanged();
    }

public:

    /**
        Whether the renderer should delegate rendering logic
        to the visual node.
    */
    override @property bool isDelegated() @nogc => true;

    /**
        Whether the node can be used as a source of masking operations.
    */
    override @property bool isMasking() @nogc nothrow pure => true;

    /**
        The blending mode
    */
    BlendMode blendingMode;

    /**
        The opacity of the composite
    */
    float opacity = 1;

    /**
        Multiplicative tint color
    */
    vec3 tint = vec3(1, 1, 1);

    /**
        Screen tint color
    */
    vec3 screenTint = vec3(0, 0, 0);

    /// Destructor
    ~this() {
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

    /**
        Notifies the composite that the visuals have changed and
        that it should re-index them.
    */
    void notifyVisualsChanged() {

        

            .findVisuals(this, visuals_, false, false, false);
    }
}

mixin Register!(Composite, in_node_registry);

//
//              IMPLEMENTATION DETAILS
//
private:
__gshared Mesh __screenSpaceMesh;

// We are allocating extra data library-wide here.
pragma(crt_constructor)
extern (C) void __in_setup_composite() {
    if (!__screenSpaceMesh) {
        uint[6] indices = [
            0, 1, 2,
            2, 1, 3
        ];
        vec2[4] uvs = [
            vec2(0, 0),
            vec2(0, 1),
            vec2(1, 0),
            vec2(1, 1)
        ];
        vec2[4] vertices = [
            vec2(-1, -1),
            vec2(-1, 1),
            vec2(1, -1),
            vec2(1, 1)
        ];
        auto meshData = MeshData(vertices, uvs, indices);
        __screenSpaceMesh = Mesh.fromMeshData(meshData);
    }
}

// And deallocating it again
pragma(crt_destructor)
extern (C) void __in_cleanup_composite() {
    __screenSpaceMesh.release();
}
