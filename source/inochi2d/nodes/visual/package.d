/**
    Inochi2D Visual Node

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.nodes.visual;
import inochi2d.nodes;
import inochi2d.common;
import inochi2d.core;
import nulib.collections;
import nulib.math.fixed;
import nulib.string;
import nulib.math;
import numem;

public import inochi2d.nodes.visual.part;
public import inochi2d.nodes.visual.animatedpart;
public import inochi2d.nodes.visual.composite;
public import inochi2d.nodes.visual.solo;
public import inochi2d.nodes.visual.mask;

/**
    A node which can be drawn to the screen.
*/
@TypeId("Visual", IN_MAKE_TAG!(0, 1))
@TypeIdAbstract
abstract
class Visual : Node {
private:
@nogc:
    int zSort_ = 0;

protected:

    /**
        Constructs a new visual
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        Constructs a new visual
    */
    this(GUID guid, Node parent = null) {
        super(guid, parent);
    }

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
    */
    override
    void onSerialize(ref DataNode object) @nogc {
        super.onSerialize(object);
        object["zsort"] = zSort_;
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
        object.tryGetRef(state, zSort_, "zsort");

        // Upgrade masks from previous format to new format.
        if (state.doUpgrade08 && !cast(Mask)this) {
            state.info(nstring("Upgrading legacy z-sorting values for ", name, "..."));
            int newZSort = cast(int)((state.upctx["zsort"]) * 100);
            this.zSort_ = newZSort;

            if ("masks" in object && object["masks"].length > 0) {
                state.info(nstring("0.8->0.9: wrapping ", this.name[], " in Mask node..."));

                // Create a new mask object to wrap ourselves in.
                Visual mask = nogc_new!Mask(inNewGUID(), this.parent);
                mask.onDeserialize(object, state);
                mask.name = "Mask";
                mask.zSort_ = newZSort;
                this.parent = mask;
            }
        }
    }

    /**
        Called when the node is to finalize its deserialization from disk.

        Params:
            state =     The state of the deserializer.
    */
    override
    void onFinalize(ref ModelState state) @nogc {
        super.onFinalize(state);
    }

    /**
        Callback for when the Visual is being requested to find its
        sub-visuals.

        Params:
            visuals =           The array to append the visuals to.
            recurseDelegates =  Whether to recurse through delegate visuals.
            append =            Whether to append to the visuals list.
    */
    void onDelegateFindVisuals(ref weak_vector!Visual visuals, bool recurseDelegates, bool append) {
    }

    /**
        Called when the node should be drawn to a mask.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
            mode =      The masking mode to draw with.
    */
    void onDrawMask(float delta, DrawList drawList, MaskingMode mode) {
    }

    /**
        Called when the node is to define its properties.

        Call $(D propList.define) with a quark to do this.

        Params:
            propList = The property list to populate.
    */
    override void onDefineProperties(ref PropertyStore propList) {
        super.onDefineProperties(propList);
        propList.define(PROP_ZSORT, 0);
    }

public:

    /**
        Whether the renderer should delegate rendering logic
        to the visual node.
    */
    @property bool isDelegated() @nogc nothrow pure => false;

    /**
        Whether the node can be used as a source of masking operations.
    */
    @property bool isMasking() @nogc nothrow pure => false;

    /**
        World-space Z-sorting value
    */
    @property ref int zSort() @nogc nothrow pure => zSort_;

    /**
        World-space z-sorting value taking in to account properties.
    */
    @property float zSortRender() @nogc nothrow pure => (zSort_ + props.get!float(PROP_ZSORT));

    /// Destructor
    ~this() {
    }

    /**
        Draws this visual as a mask.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
            mode =      The masking mode to draw with.
    */
    final void drawMask(float delta, DrawList drawList, MaskingMode mode) @nogc {
        this.onDrawMask(delta, drawList, mode);
    }

    /**
        Requests that the list gather sub-visuals to be rendered, if applicable.

        Params:
            visuals =           The list to write to, the list may be resized by the
                                implementation.
            recurseDelegates =  Whether to recurse through delegate visuals.
            append =            Whether to append to the visuals list.
    */
    void findVisuals(ref weak_vector!Visual visuals, bool recurseDelegates = false, bool append = false) {
        this.onDelegateFindVisuals(visuals, recurseDelegates, append);
    }
}

mixin Register!(Visual, in_node_registry);

//
//          QUARKS
//

mixin RegisterQuarks!();

/**
    z-sort value.
*/
@propkey("zsort")
__gshared immutable(quark) PROP_ZSORT;

/**
    Opacity.
*/
@propkey("opacity")
__gshared immutable(quark) PROP_OPACITY;

/**
    Tint RGB
*/
@propkey("tint.rgb")
__gshared immutable(quark) PROP_TINT_RGB;

/**
    Tint red
*/
@propkey("tint.r")
__gshared immutable(quark) PROP_TINT_R;

/**
    Tint green
*/
@propkey("tint.g")
__gshared immutable(quark) PROP_TINT_G;

/**
    Tint blue
*/
@propkey("tint.b")
__gshared immutable(quark) PROP_TINT_B;

/**
    Screen-tint RGB
*/
@propkey("screenTint.rgb")
__gshared immutable(quark) PROP_SCREEN_RGB;

/**
    Screen-tint red
*/
@propkey("screenTint.r")
__gshared immutable(quark) PROP_SCREEN_R;

/**
    Screen-tint green
*/
@propkey("screenTint.g")
__gshared immutable(quark) PROP_SCREEN_G;

/**
    Screen-tint blue
*/
@propkey("screenTint.b")
__gshared immutable(quark) PROP_SCREEN_B;

/**
    Emission strength
*/
@propkey("emissionStrength")
__gshared immutable(quark) PROP_EMISSION_STRENGTH;

//
//          HELPER FUNCTIONS
//

/**
    Finds visuals that are within the hirearchy of the given node.

    Params:
        root =              The root node to start looking from
        visuals =           The list to write to, the list may be resized by the
                            implementation.
        recurseDelegates =  Whether to recurse through delegate visuals.
        sort =              Whether to sort the list of visuals.
        append =            Whether to append to the visuals list.
*/
void findVisuals(Node root, ref weak_vector!Visual visuals, bool recurseDelegates = false, bool sort = true, bool append = false) @nogc {
    static void findVisualsImpl(Node node, ref weak_vector!Visual visuals, ref size_t i, bool recurseDelegates = false) @nogc {
        if (!node)
            return;

        if (auto visual = cast(Visual)node) {
            if (!visual.enabled)
                return;

            visuals ~= visual;
            if (!visual.isDelegated || recurseDelegates) {
                foreach (child; node.children) {
                    findVisualsImpl(child, visuals, i, recurseDelegates);
                }
            } else if (visual.isDelegated) {
                visual.findVisuals(visuals, recurseDelegates, true);
            }
        } else {

            // Non-part nodes just need to be recursed through,
            // they don't draw anything.
            foreach (child; node.children) {
                findVisualsImpl(child, visuals, i, recurseDelegates);
            }
        }
    }

    if (!append)
        visuals.clear();

    // Find all visuals in children.
    size_t i = 0;
    foreach (child; root.children) {
        findVisualsImpl(child, visuals, i, recurseDelegates);
    }

    if (sort)
        sortNodes(visuals.value);
}
