/**
    Inochi2D Composite Node

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.nodes.composite;
import inochi2d.nodes.visual;
import inochi2d.nodes;
import inochi2d.core.math;
import inochi2d.core;
import numem;

public import inochi2d.core.render.state;

struct CompositeVars {
align(vec4.sizeof):
    vec3 tint;
    vec3 screenTint;
    float opacity;
}

/**
    Composite Node
*/
@TypeId("Composite", 0x0301)
class Composite : Visual {
private:
@nogc:
    DrawListAlloc* ssDrawList_;
    Visual[] visuals_;

    //
    //      PARAMETER OFFSETS
    //
    float offsetOpacity = 1;
    vec3 offsetTint = vec3(0);
    vec3 offsetScreenTint = vec3(0);
protected:

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
            recursive = Whether to recurse through children.
    */
    override
    void onSerialize(ref DataNode object, bool recursive = true) {
        super.onSerialize(object, recursive);
        object["blend_mode"] = cast(uint)blendingMode;
        object["tint"] = tint.serialize();
        object["screenTint"] = screenTint.serialize();
        object["opacity"] = opacity;
        object["masks"] = masks.serialize();
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object = The DataNode to deserialize from.
    */
    override
    void onDeserialize(ref DataNode object) {
        super.onDeserialize(object);

        object.tryGetRef(opacity, "opacity");
        object.tryGetRef(tint, "tint");
        object.tryGetRef(screenTint, "screenTint");
        object.tryGetRef(masks, "masks");

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
        this.notifyVisualsChanged();
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

        offsetOpacity = 1;
        offsetTint = vec3(1, 1, 1);
        offsetScreenTint = vec3(0, 0, 0);
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
            mode =      The masking mode to draw with.
    */
    override
    void onDraw(float delta, DrawList drawList, MaskingMode mode) {
        if (visuals_.length == 0)
            return;

        CompositeVars compositeVars = CompositeVars(
                tint * offsetTint,
                screenTint * offsetScreenTint,
                opacity * offsetOpacity
        );

        visuals_.sortNodes();

        // Push sub render area.
        drawList.beginComposite();
        foreach (Node child; visuals_) {
            child.draw(delta, drawList);
        }
        drawList.endComposite();

        if (masks.length > 0) {
            foreach (ref mask; masks) {
                mask.maskSrc.onDraw(delta, drawList, mask.mode);
            }
        }

        // Then blit it to the main framebuffer
        drawList.setVariables!CompositeVars(nid, compositeVars);
        drawList.setMesh(ssDrawList_);
        drawList.setDrawState(DrawState.compositeBlit);
        drawList.setBlending(blendingMode);
        drawList.next();
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
    void onDelegateFindVisuals(ref Visual[] visuals, bool recurseDelegates, bool append) {
        this.notifyVisualsChanged();
    }

public:

    /**
        Whether the renderer should delegate rendering logic
        to the visual node.
    */
    override @property bool isDelegated() @nogc => true;

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

    /**
        List of masks to apply
    */
    MaskBinding[] masks;

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
        case "opacity":
        case "tint.r":
        case "tint.g":
        case "tint.b":
            return 1;
        case "screenTint.r":
        case "screenTint.g":
        case "screenTint.b":
            return 0;
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
        default:
            super.setProperty(key, value);
            return;
        }
    }

    /**
        Notifies the composite that the visuals have changed and
        that it should re-index them.
    */
    void notifyVisualsChanged() {
        .findVisuals(this, visuals_, true, false, false);
        sortNodes(visuals_);
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
        __screenSpaceMesh = Mesh.fromMeshData(MeshData(vertices, uvs, indices));
    }
}

// And deallocating it again
pragma(crt_destructor)
extern (C) void __in_cleanup_composite() {
    __screenSpaceMesh.release();
}
