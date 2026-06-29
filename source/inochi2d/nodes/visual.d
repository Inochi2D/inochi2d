/**
    Inochi2D Visual Node

    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna Nielsen
*/
module inochi2d.nodes.visual;
import inochi2d.nodes;
import inochi2d.core.math;
import inochi2d.core;
import nulib.collections;
import nulib.math.fixed;
import nulib.math;
import numem;

/**
    A node which can be drawn to the screen.
*/
@TypeId("Visual", 0x0001)
@TypeIdAbstract
abstract
class Visual : Node {
private:
@nogc:
    vector!MaskBinding masks_;
    size_t maskCount_;
    size_t dodgeCount_;

    void updateCounts() {
        maskCount_ = 0;
        dodgeCount_ = 0;
        foreach (m; masks) {
            if (m.mode == MaskingMode.mask)
                maskCount_++;
            if (m.mode == MaskingMode.dodge)
                dodgeCount_++;
        }
    }

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
    void onSerialize(ref DataNode object) {
        super.onSerialize(object);

        // Serialize masks, if any are applied.
        if (masks_.length > 0) {
            object["masks"] = DataNode.createArray();
            foreach (mask; masks_) {
                object["masks"] ~= mask.serialize();
            }
        }
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object = The DataNode to deserialize from.
    */
    override
    void onDeserialize(ref DataNode object) {
        super.onDeserialize(object);

        // Deserialize masks, if any are present.
        if ("masks" in object && object["masks"].isArray) {
            masks_.resize(object["masks"].length);
            foreach (i, ref DataNode value; object["masks"].array) {
                masks_[i] = value.deserialize!MaskBinding();
            }
        }
    }

    /**
        Called when the node is to finalize its deserialization from disk.
    */
    override
    void onFinalize() @nogc {
        super.onFinalize();

        foreach_reverse (i; 0 .. masks_.length) {
            if (Visual nMask = puppet.find!Visual(masks_[i].maskSrcGUID)) {
                masks_[i].maskSrc = nMask;
                continue;
            }

            // Mask not found, remove index.
            masks_.removeAt(i);
        }
        this.updateCounts();
    }

    /**
        Callback for when the Visual is being requested to find its
        sub-visuals.

        Params:
            visuals =           The array to append the visuals to.
            recurseDelegates =  Whether to recurse through delegate visuals.
            append =            Whether to append to the visuals list.
    */
    void onDelegateFindVisuals(ref weak_vector!Visual visuals, bool recurseDelegates, bool append) { }

public:

    /**
        The amount of masks in $(D Mask) mode applied to this Visual.
    */
    @property size_t maskCount() pure => maskCount_;

    /**
        The amount of masks in $(D Dodge) mode applied to this Visual.
    */
    @property size_t dodgeCount() pure => dodgeCount_;

    /**
        List of masks to apply
    */
    @property MaskBinding[] masks() => masks_[0 .. $];

    /**
        Whether the renderer should delegate rendering logic
        to the visual node.
    */
    @property bool isDelegated() @nogc nothrow pure => false;

    /// Destructor
    ~this() {
        masks_.clear();
    }

    /**
        Gets whether this visual is masked by the given other visual.

        Params:
            visual = The visual to query.

        Returns:
            $(D true) if this visual is masked by $(D visual),
            $(D false) otherwise.
    */
    bool isMaskedBy(Visual visual) {
        foreach (mask; masks) {
            if (mask.maskSrc.guid == visual.guid)
                return true;
        }
        return false;
    }

    /**
        Gets the mask index of the given visual.

        Params:
            visual = The visual to search for.
        
        Returns:
            Positive integer on success,
            $(D -1) if the visual was not found.
    */
    ptrdiff_t getMaskIndex(Visual visual) {
        if (visual is null)
            return -1;

        foreach (i, ref mask; masks) {
            if (mask.maskSrc.guid == visual.guid)
                return i;
        }
        return -1;
    }

    /**
        Gets the mask index of the given visual.

        Params:
            guid = The GUID of the visual to search for.
        
        Returns:
            Positive integer on success,
            $(D -1) if the visual was not found.
    */
    ptrdiff_t getMaskIndex(GUID guid) {
        foreach (i, ref mask; masks) {
            if (mask.maskSrc.guid == guid)
                return i;
        }
        return -1;
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

/**
    A binding between a mask and a mode
*/
struct MaskBinding {
public:
    GUID maskSrcGUID;
    MaskingMode mode;
    Visual maskSrc;

    /**
        Serialization function
    */
    void onSerialize(ref DataNode object, bool recursive = true) @nogc {
        auto srcGuid = maskSrcGUID.toString();
        object["source"] = srcGuid[];
        object["mode"] = cast(uint)mode;
    }

    /**
        Deserialization function
    */
    void onDeserialize(ref DataNode object) @nogc {
        maskSrcGUID = object.tryGetGUID("source", "source");
        mode = object.tryGet!string("mode", null).toMaskingMode;
    }
}

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
    foreach(child; root.children) {
        findVisualsImpl(child, visuals, i, recurseDelegates);
    }

    if (sort)
        sortNodes(visuals.value);
}
