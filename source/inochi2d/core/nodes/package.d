/*
    Inochi2D Node

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes;
import inochi2d.core.format;
import inochi2d.core.math;
import inochi2d.core.guid;
import inochi2d.core;
import nulib.string;

public import inochi2d.core.nodes.drawable;
public import inochi2d.core.nodes.composite;
public import inochi2d.core.nodes.deformer;
public import inochi2d.core.nodes.drivers; 
public import inochi2d.core.registry;

import core.attribute : standalone;
import std.exception;

/**
    The public node registry.
*/
__gshared TypeRegistry!Node in_node_registry;

/**
    A node in the Inochi2D rendering tree
*/
@TypeId("Node", 0x00000000)
class Node : ISerializable, IDeserializable {
private:
    Puppet puppet_;
    Node parent_;
    Node[] children_;
    GUID guid_;
    float zsort_ = 0;
    bool lockToRoot_;
    string nodePath_;
    uint nid_;

package(inochi2d):

    /**
        Needed for deserialization
    */
    void setPuppet(Puppet puppet) {
        this.puppet_ = puppet;
    }

protected:

    /**
        The Node's numeric ID
    */
    final @property uint nid() => nid_;

    bool recalculateTransform = true;
    bool preProcessed  = false;
    bool postProcessed = false;

    /**
        The offset to the transform to apply
    */
    Transform offsetTransform;

    /**
        The offset to apply to sorting
    */
    float offsetSort = 0f;

    // Send mask reset request one node up
    void resetMask() {
        if (parent !is null) parent.resetMask();
    }

public:

    /**
        Whether the node is enabled
    */
    bool enabled = true;

    /**
        Visual name of the node
    */
    nstring name = "Unnamed Node";

    /**
        The Node's Type ID
    */
    final @property TypeId typeId() => in_node_registry.lookup(this);

    /**
        The node's GUID.
    */
    @property GUID guid() => guid_;

    /**
        Whether the node is enabled for rendering

        Disabled nodes will not be drawn.

        This happens recursively
    */
    @property bool renderEnabled() => parent ? (!parent.renderEnabled ? false : enabled) : enabled;

    /**
        The relative Z sorting
    */
    @property ref float relZSort() => zsort_;

    /**
        The basis zSort offset.
    */
    @property float zSortBase() => parent !is null ? parent.zSort() : 0;

    /**
        The Z sorting without parameter offsets
    */
    @property float zSortNoOffset() => zSortBase + relZSort;

    /**
        The Z sorting
    */
    @property float zSort() => zSortBase + relZSort + offsetSort;
    @property void zSort(float value) {
        zsort_ = value;
    }

    /**
        Lock translation to root
    */
    @property bool lockToRoot() => lockToRoot_;
    @property void lockToRoot(bool value) {
        
        // Automatically handle converting lock space and proper world space.
        if (value && !lockToRoot_) {
            localTransform.translation = transformNoLock().translation;
        } else if (!value && lockToRoot_) {
            localTransform.translation = localTransform.translation-parent.transformNoLock().translation;
        }

        lockToRoot_ = value;
    }

    /**
        Constructs a new puppet root node
    */
    this(Puppet puppet) {
        this.puppet_ = puppet;
    }

    /**
        Constructs a new node
    */
    this(Node parent = null) {
        this(inNewGUID(), parent);
    }

    /**
        Constructs a new node with an UUID
    */
    this(GUID guid, Node parent = null) {
        this.parent = parent;
        this.guid_ = guid;
    }

    /**
        The local transform of the node
    */
    Transform localTransform;

    /**
        The cached world space transform of the node
    */
    Transform globalTransform;

    /**
        The transform in world space
    */
    Transform transform(bool ignoreParam=false)() {
        if (recalculateTransform) {
            localTransform.update();
            offsetTransform.update();

            static if (!ignoreParam) {
                if (lockToRoot_)
                    globalTransform = localTransform.calcOffset(offsetTransform) * puppet.root.localTransform;
                else if (parent !is null)
                    globalTransform = localTransform.calcOffset(offsetTransform) * parent.transform();
                else
                    globalTransform = localTransform.calcOffset(offsetTransform);

                recalculateTransform = false;
            } else {

                if (lockToRoot_)
                    globalTransform = localTransform * puppet.root.localTransform;
                else if (parent !is null)
                    globalTransform = localTransform * parent.transform();
                else
                    globalTransform = localTransform;

                recalculateTransform = false;
            }
        }

        return globalTransform;
    }

    /**
        The transform in world space without locking
    */
    Transform transformLocal() {
        localTransform.update();
        
        return localTransform.calcOffset(offsetTransform);
    }

    /**
        The transform in world space without locking
    */
    Transform transformNoLock() {
        localTransform.update();
        
        if (parent !is null) return localTransform * parent.transform();
        return localTransform;
    }

    /**
        Calculates the relative position between 2 nodes and applies the offset.
        You should call this before reparenting nodes.
    */
    void setRelativeTo(Node to) {
        setRelativeTo(to.transformNoLock.matrix);
        this.zSort = this.zSortNoOffset-to.zSortNoOffset;
    }

    /**
        Calculates the relative position between this node and a matrix and applies the offset.
        This does not handle zSorting. Pass a Node for that.
    */
    void setRelativeTo(mat4 to) {
        this.localTransform.translation = getRelativePosition(to, this.transformNoLock.matrix);
        this.localTransform.update();
    }

    /**
        Gets a relative position for 2 matrices
    */
    static
    vec3 getRelativePosition(mat4 m1, mat4 m2) {
        mat4 cm = (m1.inverse * m2).translation;
        return vec3(cm.matrix[0][3], cm.matrix[1][3], cm.matrix[2][3]);
    }

    /**
        Gets a relative position for 2 matrices

        Inverse order of getRelativePosition
    */
    static
    vec3 getRelativePositionInv(mat4 m1, mat4 m2) {
        mat4 cm = (m2 * m1.inverse).translation;
        return vec3(cm.matrix[0][3], cm.matrix[1][3], cm.matrix[2][3]);
    }

    /**
        Gets the path to the node.
    */
    final
    string getNodePath() {
        import std.array : join;
        if (nodePath_.length > 0) return nodePath_;

        string[] pathSegments;
        Node parent = this;
        while(parent !is null) {
            pathSegments = parent.name ~ pathSegments;
            parent = parent.parent;
        }
        
        nodePath_ = "/"~pathSegments.join("/");
        return nodePath_;
    }

    /**
        Gets the depth of this node
    */
    final int depth() {
        int depthV;
        Node parent = this;
        while(parent !is null) {
            depthV++;
            parent = parent.parent;
        }
        return depthV;
    }

    /**
        Gets a list of this node's children
    */
    final Node[] children() {
        return children_;
    }

    /**
        The parent of this node
    */
    final @property Node parent() => parent_;
    final @property void parent(Node node) {
        this.insertInto(node, OFFSET_END);
    }

    /**
        The puppet this node is attached to
    */
    final Puppet puppet() {
        return parent_ !is null ? parent_.puppet : puppet_;
    }

    /**
        Removes all children from this node
    */
    final void clearChildren() {
        foreach(child; children_) {
            child.parent_ = null;
        }
        this.children_ = [];
    }

    /**
        Adds a node as a child of this node.
    */
    final void addChild(Node child) {
        child.parent = this;
    }

    final ptrdiff_t getIndexInParent() {
        import std.algorithm.searching : countUntil;
        return parent_.children_.countUntil(this);
    }

    final ptrdiff_t getIndexInNode(Node n) {
        import std.algorithm.searching : countUntil;
        return n.children_.countUntil(this);
    }

    enum OFFSET_START = size_t.min;
    enum OFFSET_END = size_t.max;
    final void insertInto(Node node, size_t offset) {
        nodePath_ = null;
        import std.algorithm.mutation : remove;
        import std.algorithm.searching : countUntil;
        
        // Remove ourselves from our current parent if we are
        // the child of one already.
        if (parent_ !is null) {
            
            // Try to find ourselves in our parent
            // note idx will be -1 if we can't be found
            ptrdiff_t idx = parent_.children_.countUntil(this);
            assert(idx >= 0, "Invalid parent-child relationship!");

            // Remove ourselves
            parent_.children_ = parent_.children_.remove(idx);
        }

        // If we want to become parentless we need to handle that
        // seperately, as null parents have no children to update
        if (node is null) {
            this.parent_ = null;
            return;
        }

        // Update our relationship with our new parent
        this.parent_ = node;

        // Update position
        if (offset == OFFSET_START) {
            this.parent_.children_ = this ~ this.parent_.children_;
        } else if (offset == OFFSET_END || offset >= parent_.children_.length) {
            this.parent_.children_ ~= this;
        } else {
            this.parent_.children_ = this.parent_.children_[0..offset] ~ this ~ this.parent_.children_[offset..$];
        }
        if (this.puppet !is null) this.puppet.rescanNodes();
    }

    /**
        Return whether this node supports a parameter
    */
    bool hasParam(string key) {
        switch(key) {
            case "zSort":
            case "transform.t.x":
            case "transform.t.y":
            case "transform.t.z":
            case "transform.r.x":
            case "transform.r.y":
            case "transform.r.z":
            case "transform.s.x":
            case "transform.s.y":
                return true;
            default:
                return false;
        }
    }

    /**
        Gets the default offset value
    */
    float getDefaultValue(string key) {
        switch(key) {
            case "zSort":
            case "transform.t.x":
            case "transform.t.y":
            case "transform.t.z":
            case "transform.r.x":
            case "transform.r.y":
            case "transform.r.z":
                return 0;
            case "transform.s.x":
            case "transform.s.y":
                return 1;
            default:
                return float();
        }
    }

    /**
        Sets offset value
    */
    bool setValue(string key, float value) {
        switch(key) {
            case "zSort":
                offsetSort += value;
                return true;
            case "transform.t.x":
                offsetTransform.translation.x += value;
                transformChanged();
                return true;
            case "transform.t.y":
                offsetTransform.translation.y += value;
                transformChanged();
                return true;
            case "transform.t.z":
                offsetTransform.translation.z += value;
                transformChanged();
                return true;
            case "transform.r.x":
                offsetTransform.rotation.x += value;
                transformChanged();
                return true;
            case "transform.r.y":
                offsetTransform.rotation.y += value;
                transformChanged();
                return true;
            case "transform.r.z":
                offsetTransform.rotation.z += value;
                transformChanged();
                return true;
            case "transform.s.x":
                offsetTransform.scale.x *= value;
                transformChanged();
                return true;
            case "transform.s.y":
                offsetTransform.scale.y *= value;
                transformChanged();
                return true;
            default: return false;
        }
    }

    /**
        Scale an offset value, given an axis and a scale

        If axis is -1, apply magnitude and sign to signed properties.
        If axis is 0 or 1, apply magnitude only unless the property is
        signed and aligned with that axis.

        Note that scale adjustments are not considered aligned,
        since we consider preserving aspect ratio to be the user
        intent by default.
    */
    float scaleValue(string key, float value, int axis, float scale) {
        if (axis == -1) return value * scale;

        float newVal = abs(scale) * value;
        switch(key) {
            case "transform.r.z": // Z-rotation is XY-mirroring
                newVal = scale * value;
                break;
            case "transform.r.y": // Y-rotation is X-mirroring
            case "transform.t.x":
                if (axis == 0) newVal = scale * value;
                break;
            case "transform.r.x": // X-rotation is Y-mirroring
            case "transform.t.y":
                if (axis == 1) newVal = scale * value;
                break;
            default:
                break;
        }
        return newVal;
    }

    float getValue(string key) {
        switch(key) {
            case "zSort":           return offsetSort;
            case "transform.t.x":   return offsetTransform.translation.x;
            case "transform.t.y":   return offsetTransform.translation.y;
            case "transform.t.z":   return offsetTransform.translation.z;
            case "transform.r.x":   return offsetTransform.rotation.x;
            case "transform.r.y":   return offsetTransform.rotation.y;
            case "transform.r.z":   return offsetTransform.rotation.z;
            case "transform.s.x":   return offsetTransform.scale.x;
            case "transform.s.y":   return offsetTransform.scale.y;
            default:                return 0;
        }
    }

    /**
        Update sequence run before the main update sequence.
    */
    void preUpdate(DrawList drawList) {
        offsetTransform.clear();
        offsetSort = 0;

        if (!enabled) return;
        foreach(child; children_) {
            child.preUpdate(drawList);
        }
    }

    /**
        Updates the node
    */
    void update(float delta, DrawList drawList) {

        if (!enabled) return;
        foreach(child; children) {
            child.update(delta, drawList);
        }
    }

    /**
        Update sequence run after the main update sequence.
    */
    void postUpdate(DrawList drawList) {
        
        if (!enabled) return;
        foreach(child; children_) {
            child.postUpdate(drawList);
        }
    }

    /**
        Draws this node and it's subnodes
    */
    void draw(float delta, DrawList drawList) { }

    /**
        Marks this node's transform (and its descendents') as dirty
    */
    void transformChanged() {
        recalculateTransform = true;

        foreach(child; children) {
            child.transformChanged();
        }
    }

    override string toString() const {
        return name[];
    }

    void onSerialize(ref JSONValue object, bool recursive = true) {
        nstring guid = guid_.toString();
        object["guid"] = guid.dup;
        object["name"] = name;
        object["type"] = typeId.sid;
        object["enabled"] = enabled;
        object["zsort"] = zsort_;
        object["transform"] = zsort_;
        object["lockToRoot"] = lockToRoot_;

        // Allow non-recursive serialization.
        if (!recursive)
            return;

        object["children"] = JSONValue.emptyArray;
        foreach(child; children) {
            object["children"].array ~= child.serialize();
        }
    }

    /**
        Deserializes node from JSONValue formatted JSON data.
    */
    void onDeserialize(ref JSONValue object) {
        this.guid_ = object.tryGetGUID("uuid", "guid");
        object.tryGetRef(name, "name");
        object.tryGetRef(enabled, "enabled");
        object.tryGetRef(zsort_, "zsort");
        object.tryGetRef(localTransform, "transform");
        object.tryGetRef(lockToRoot_, "lockToRoot");

        // Pre-populate our children with the correct types
        if (object.isJsonArray("children")) {
            foreach(child; object["children"].array) {
                
                // Fetch type from json
                if (string type = child.tryGet!string("type", null)) {

                    // Skips unknown node types
                    // TODO: A logging system that shows a warning for this?
                    if (!in_node_registry.has(type))
                        continue;

                    // NOTE:    inInstantiateNode implicitly handles setting the
                    //          Parent-child relationship, so we don't need to do
                    //          anything else besides pass it onto the child's
                    //          deserializer.
                    Node n = in_node_registry.create(type);
                    n.parent = this;
                    child.deserialize(n);
                }
            }
        }
    }

    /**
        Reconstructs a child.
    */
    void reconstruct() {
        foreach(child; children.dup) {
            child.reconstruct();
        }
    }

    /**
        Finalizes this node and any children
    */
    void finalize() {
        nid_ = typeId.nid;
        foreach(child; children) {
            child.finalize();
        }
    }

    rect getCombinedBoundsRect(bool reupdate = false, bool countPuppet=false)() {
        vec4 combinedBounds = getCombinedBounds!(reupdate, countPuppet)();
        return rect(
            combinedBounds.x, 
            combinedBounds.y, 
            combinedBounds.z-combinedBounds.x, 
            combinedBounds.w-combinedBounds.y
        );
    }

    vec4 getInitialBoundsSize() {
        auto tr = transform;
        return vec4(tr.translation.x, tr.translation.y, tr.translation.x, tr.translation.y);
    }

    /**
        Gets the combined bounds of the node
    */
    vec4 getCombinedBounds(bool reupdate = false, bool countPuppet=false)() {
        vec4 combined = getInitialBoundsSize();
        
        // Get Bounds as drawable
        if (Drawable drawable = cast(Drawable)this) {
            if (reupdate) drawable.updateBounds();
            combined = drawable.bounds;
        }

        foreach(child; children) {
            vec4 cbounds = child.getCombinedBounds!(reupdate)();
            if (cbounds.x < combined.x) combined.x = cbounds.x;
            if (cbounds.y < combined.y) combined.y = cbounds.y;
            if (cbounds.z > combined.z) combined.z = cbounds.z;
            if (cbounds.w > combined.w) combined.w = cbounds.w;
        }

        static if (countPuppet) {
            return vec4(
                (puppet.transform.matrix*vec4(combined.xy, 0, 1)).xy,
                (puppet.transform.matrix*vec4(combined.zw, 0, 1)).xy,
            );
        } else {
            return combined;
        }
    }

    /**
        Gets whether nodes can be reparented
    */
    bool canReparent(Node to) {
        Node tmp = to;
        while(tmp !is null) {
            if (tmp.guid == this.guid) return false;
            
            // Check next up
            tmp = tmp.parent;
        }
        return true;
    }

    /** 
        Set new Parent
    */
    void reparent(Node parent, ulong pOffset) {
        if (parent !is null)
            setRelativeTo(parent);
        insertInto(parent, pOffset);
    }
}
mixin Register!(Node, in_node_registry);
