/**
    Inochi2D Solo Node

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.nodes.visual.solo;
import inochi2d.nodes.visual;
import inochi2d.nodes;
import inochi2d.core.math;
import inochi2d.core;
import nulib;
import numem;

/**
    A node which only allows a single child node to be displayed
    at a time.
*/
@TypeId("Solo", IN_MAKE_TAG!(4, 1))
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
    void onDelegateFindVisuals(ref weak_vector!Visual visuals, bool recurseDelegates, bool append) {
        if (children.length > 0) {
            .findVisuals(children[activeLayer_], visuals, recurseDelegates, false, append);
        }
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
        propList.define(PROP_ACTIVE_LAYER, 0);
    }

public:

    /**
        Whether the renderer should delegate rendering logic
        to the visual node.
    */
    override @property bool isDelegated() @nogc nothrow pure => true;

    /**
        Whether the node can be used as a source of masking operations.
    */
    override @property bool isMasking() @nogc nothrow pure => true;
    
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
}
mixin Register!(Solo, in_node_registry);




//
//          QUARKS
//

mixin RegisterQuarks!();

/**
    Active layer.
*/
@propkey("activeLayer")
__gshared immutable(quark) PROP_ACTIVE_LAYER;
