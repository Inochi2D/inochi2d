/**
    Inochi2D Solo Node

    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna Nielsen
*/
module inochi2d.nodes.solo;
import inochi2d.nodes.visual;
import inochi2d.nodes;
import inochi2d.core.math;
import inochi2d.core;
import numem;

/**
    A node which only allows a single child node to be displayed
    at a time.
*/
@TypeId("Solo", 0x0401)
class Solo : Visual {
private:
@nogc:
    uint lastActiveLayer_;
    uint activeLayer_;

    void changeLayer(uint value) @nogc nothrow {
        this.lastActiveLayer_ = clamp(activeLayer_, 0, cast(uint)children.length);
        this.activeLayer_ = clamp(cast(uint)value, 0, cast(uint)children.length);
    }

protected:

    /**
        Called during the early update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onPreUpdate(DrawList drawList) {

        // NOTE:    If we changed the active layer, force the puppet to rescan its visuals
        //          hirearchy.
        //          We do this since we want the Solo's hirearchy to blend
        //          with the outer hirearchy sorting wise.
        if (lastActiveLayer_ != activeLayer_)
            puppet.rescanNodes();
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
        if (children.length > 0) {
            .findVisuals(children[activeLayer_], visuals, recurseDelegates, false, append);
        }
    }

public:

    /**
        Whether the renderer should delegate rendering logic
        to the visual node.
    */
    override @property bool isDelegated() @nogc nothrow pure => true;
    
    /**
        The active layer that will be rendered.
    */
    final @property Node activeLayer() @nogc nothrow pure => children.length > 0 ? children[activeLayer_] : null;

    /**
        Constructs a new Solo node.

        Params:
            parent = The parent of the solo node.
    */
    this(Node parent = null) {
        super(inNewGUID(), parent);
    }

    /**
        Constructs a new Solo node.

        Params:
            guid =      The new GUID of the
            parent =    The parent of the solo node.
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
    bool hasProperty(string key) const @nogc nothrow {
        switch (key) {
        case "activeLayer":
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
    float getProperty(string key) const @nogc nothrow {
        switch (key) {
        case "activeLayer":
            return activeLayer_;
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
    float getPropertyDefault(string key) const @nogc nothrow {
        switch (key) {
        case "activeLayer":
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
    void setProperty(string key, float value) @nogc nothrow {
        switch (key) {
        case "activeLayer":
            this.changeLayer(cast(uint)value);
            return;
        default:
            return super.setProperty(key, value);
        }
    }
}
mixin Register!(Solo, in_node_registry);
