/**
    Inochi2D Mask Node

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.nodes.visual.mask;
import inochi2d.nodes;
import inochi2d.common;
import inochi2d.core;
import nulib.collections;
import nulib.math.fixed;
import nulib.string;
import nulib.conv;
import nulib.math;
import numem;

public import inochi2d.core.render.state;

/**
    A binding between a mask and a mode
*/
struct MaskSource {
private:
@nogc:
    GUID maskSrcGUID;

public:
    MaskingMode mode;
    Visual maskSrc;

    /**
        Serialization function
    */
    void onSerialize(ref DataNode object, bool recursive = true) {
        if (maskSrc) {
            auto srcGuid = maskSrc.guid.toString();
            object["source"] = srcGuid[];
            object["mode"] = cast(uint)mode;
        }
    }

    /**
        Deserialization function
    */
    void onDeserialize(ref DataNode object, ref ModelState state) {
        
        // 0.8 uses a string for the masking mode.
        if (state.doUpgrade08) {
            this.maskSrcGUID = object.tryGetGUID(state, "source", "source");
            this.mode = object.tryGet!nstring(state, "mode").toMaskingMode;
            return;
        }

        this.maskSrcGUID = object.tryGetGUID(state, "source", "source");
        this.mode = cast(MaskingMode)object.tryGet!uint(state, "mode");
    }

    /**
        Finalizer
    */
    void onFinalize(Mask mask) {
        this.maskSrc = mask.puppet.find!Visual(maskSrcGUID);
    }
}

/**
    A mask.
*/
@TypeId("Mask", MAKE_I2D_TAG!(5, 1))
class Mask : Visual {
private:
@nogc:
    weak_vector!Visual visuals_;
    vector!MaskSource sources_;

protected:

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
    */
    override
    void onSerialize(ref DataNode object) {
        super.onSerialize(object);

        // Serialize masks, if any are applied.
        if (sources_.length > 0) {
            object["masks"] = DataNode.createArray();
            foreach (mask; sources_) {
                object["masks"] ~= mask.serialize();
            }
        }
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

        // Deserialize masks, if any are present.
        if ("masks" in object && object["masks"].isArray) {
            sources_.resize(object["masks"].length);
            foreach (i, ref value; object["masks"].array) {
                sources_[i] = value.deserialize!MaskSource(state);
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

        // Finalize all masks.
        foreach_reverse(i; 0..sources_.length) {
            sources_[i].onFinalize(this);

            // Remove invalid masks.
            if (!sources_[i].maskSrc) {
                state.warning(nstring("Removed mask source ", i.toString(), " from ", this.name[], ", ID was invalid..."));
                sources_.removeAt(i);
            }
        }
    }

    /**
        Called when the node is to be redrawn.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
    */
    override
    void onDraw(float delta, DrawList drawList) {
        if (!enabled)
            return;

        if (sources_.length > 0) {
            drawList.pushMask(sources_[0].mode);

            visuals_.sortNodes();
            foreach(ref src; sources_) {
                src.maskSrc.drawMask(delta, drawList, src.mode);
            }

            foreach (ref child; visuals_) {
                child.draw(delta, drawList);
            }
            drawList.popMask();
            return;
        }

        // No mask sources, just draw children.
        visuals_.sortNodes();
        foreach (ref child; visuals_) {
            child.draw(delta, drawList);
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
        .findVisuals(this, visuals_, false, false, false);
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
    override @property bool isMasking() @nogc nothrow pure => false;

    /**
        List of mask sources.
    */
    @property MaskSource[] sources() => sources_[0 .. $];

    /// Destructor
    ~this() {
        sources_.clear();
    }

    /**
        Constructs a new Mask
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        Constructs a new Mask
    */
    this(GUID guid, Node parent = null) {
        super(guid, parent);
    }
}
mixin Register!(Mask, in_node_registry);