/**
    Inochi2D Visual Node

    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.visual;
import inochi2d.core.nodes;
import inochi2d.core.math;
import inochi2d.core;
import numem;

/**
    A node which can be drawn to the screen.
*/
@TypeId("Visual", 0x0001)
@TypeIdAbstract
abstract class Visual : Node {
public:

    /**
        Whether the renderer should delegate rendering logic
        to the visual node.
    */
    @property bool isDelegated() @nogc => false;
}
mixin Register!(Visual, in_node_registry);

/**
    Finds visuals that are within the hirearchy of the given node.

    Params:
        root =              The root node to start looking from
        list =              The list to write to, the list may be resized by the
                            implementation.
        recurseDelegates =  Whether to recurse through delegate visuals.
*/
void findVisuals(Node root, ref Visual[] list, bool recurseDelegates=false) @nogc {
    static void findVisualsImpl(Node node, ref Visual[] list, bool recurseDelegates=false) @nogc {
        if (!node) return;
        
        if (auto visual = cast(Visual)node) {
            if (!visual.enabled)
                return;
            
            list = list.nu_resize(list.length+1);
            list[$-1] = visual;

            if (!visual.isDelegated || recurseDelegates) {
                foreach(child; node.children) {
                    child.findVisualsImpl(list, recurseDelegates);
                }
            }
        } else {
            foreach(child; node.children) {
                child.findVisualsImpl(list, recurseDelegates);
            }
        }
    }

    nu_freea(list);
    root.findVisualsImpl(list, recurseDelegates);
}

/**
    Sort nodes by their
*/
void sortNodes(ref Node[] nodes) {

}

/**
    A binding between a mask and a mode
*/
struct MaskBinding {
public:
    GUID maskSrcGUID;
    MaskingMode mode;
    Drawable maskSrc;

    /**
        Serialization function
    */
    void onSerialize(ref JSONValue object, bool recursive = true) {
        auto srcGuid = maskSrcGUID.toString();
        object["source"] = srcGuid.dup;
        object["mode"] = mode;
    }

    /**
        Deserialization function
    */
    void onDeserialize(ref JSONValue object) {
        maskSrcGUID = object.tryGetGUID("source", "source");
        mode = object.tryGet!string("mode", null).toMaskingMode;
    }
}