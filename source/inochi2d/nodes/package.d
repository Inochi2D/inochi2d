/*
    Inochi2D Node

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.nodes;
import inochi2d.core.serde;
import inochi2d.core.math;
import inochi2d.core.guid;
import inochi2d.core;
import nulib.string;
import numem;
import nulib;

public import inochi2d.puppet;
public import inochi2d.nodes.composite;
public import inochi2d.nodes.deformer;
public import inochi2d.nodes.legacy;
public import inochi2d.nodes.visual;
public import inochi2d.nodes.part;
public import inochi2d.nodes.animatedpart;
public import inochi2d.core.registry;
public import inochi2d.core.property;
public import inochi2d.core.render;

/**
    The public node registry.
*/
__gshared TypeRegistry!Node in_node_registry;

/**
    A node in the Inochi2D rendering tree
*/
@TypeId("Node", 0x00000000)
class Node : NuRefCounted, IPropertyOwner, ISerializable, IDeserializable {
private:
@nogc:
    Puppet puppet_;
    Node parent_;
    weak_vector!Node children_;
    GUID guid_;
    bool lockToRoot_;
    string nodePath_;
    uint nid_;

    bool recalculateTransform_ = true;
    Transform globalTransform_;
    Transform globalTransformNoParam_;
    offset_value!Transform localTransform_;
    offset_value!float zSort_;
    void recalculateTransforms() {
        if (recalculateTransform_) {
            localTransform_.base.update();
            localTransform_.offset.update();
            if (lockToRoot_) {
                globalTransform_ = (localTransform_.base + localTransform_.offset) * puppet.root.localTransform_.base;
                globalTransformNoParam_ = localTransform_.base * puppet.root.localTransform_.base;
            } else if (parent !is null) {
                globalTransform_ = (localTransform_.base + localTransform_.offset) * parent.transform();
                globalTransformNoParam_ = localTransform_.base * parent.transform();
            } else {
                globalTransform_ = (localTransform_.base + localTransform_.offset);
                globalTransformNoParam_ = localTransform_.base;
            }
        }
    }

package(inochi2d):

    /**
        Needed for deserialization
    */
    void setPuppet(Puppet puppet) @nogc {
        this.puppet_ = puppet;
    }

protected:

    /**
        The Node's numeric ID
    */
    final @property uint nid() @nogc pure => nid_;

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
            recursive = Whether to recurse through children.
    */
    void onSerialize(ref DataNode object, bool recursive = true) @nogc {
        nstring guid = guid_.toString();
        object["guid"] = guid[];
        object["name"] = name[];
        object["type"] = typeId.sid;
        object["enabled"] = enabled;
        object["zsort"] = zSort_.base;
        object["transform"] = localTransform_.base.serialize();
        object["lockToRoot"] = lockToRoot_;

        // Recurse through children if enabled.
        if (recursive) {
            object["children"] = DataNode.createArray();
            foreach (child; children) {
                auto childObject = DataNode.createObject();
                child.serialize(childObject);

                object["children"] ~= childObject;
            }
        }
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object = The DataNode to deserialize from.
    */
    void onDeserialize(ref DataNode object) @nogc {

        this.guid_ = object.tryGetGUID("uuid", "guid");
        object.tryGetRef(name, "name");
        object.tryGetRef(enabled, "enabled");
        object.tryGetRef(zSort_.base, "zsort");
        object.tryGetRef(localTransform_.base, "transform");
        object.tryGetRef(lockToRoot_, "lockToRoot");

        // Pre-populate our children with the correct types
        if ("children" in object && object["children"].isArray) {
            foreach (ref child; object["children"].array) {

                // NOTE:    inInstantiateNode implicitly handles setting the
                //          Parent-child relationship, so we don't need to do
                //          anything else besides pass it onto the child's
                //          deserializer.
                if (Node n = in_node_registry.tryCreateFrom(child)) {
                    n.parent = this;
                    child.deserialize(n);
                }
            }
        }
    }

    /**
        Called when the node is to finalize its deserialization from disk.
    */
    void onFinalize() @nogc {
        nid_ = typeId.nid;
        foreach (child; children) {
            child.onFinalize();
        }
    }

    /**
        Called during the early update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    void onPreUpdate(DrawList drawList) @nogc {
    }

    /**
        Called during the update phase of a new frame.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
    */
    void onUpdate(float delta, DrawList drawList) @nogc {
    }

    /**
        Called during the late update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    void onPostUpdate(DrawList drawList) @nogc {
    }

    /**
        Called when the node is to be redrawn.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
            mode =      The masking mode to draw with.
    */
    void onDraw(float delta, DrawList drawList, MaskingMode mode = MaskingMode.none) @nogc {
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
        The puppet this node is attached to
    */
    final @property Puppet puppet() @nogc nothrow pure => parent_ !is null ? parent_.puppet : puppet_;

    /**
        The parent of this node
    */
    final @property Node parent() @nogc nothrow pure => parent_;
    final @property void parent(Node node) @nogc {
        this.insertInto(node, OFFSET_END);
    }

    /**
        Gets a list of this node's children
    */
    final @property Node[] children() @nogc nothrow pure => children_;

    /**
        The Node's Type ID
    */
    final @property TypeId typeId() @nogc => in_node_registry.lookup(this);

    /**
        The node's GUID.
    */
    @property GUID guid() @nogc nothrow pure => guid_;

    /**
        Local-space Z-sorting value
    */
    @property ref float localZSort() @nogc nothrow pure => zSort_.base;

    /**
        World-space Z-sorting value
    */
    @property float zSort() @nogc nothrow pure => (parent ? parent.zSort : 0) + zSort_;

    /**
        The transform in local-space.
    */
    @property ref Transform localTransform() @nogc => localTransform_.base;

    /**
        The offset transform in local-space.
    */
    @property ref Transform localTransformOffset() @nogc => localTransform_.offset;

    /**
        The transform in world space without locking
    */
    @property Transform transformNoLock() @nogc {
        localTransform_.base.update();

        if (parent !is null)
            return localTransform_.base * parent.transform();
        return localTransform_.base;
    }

    /**
        The transform in world space
    */
    @property Transform transform(bool ignoreParams = false)() @nogc {
        this.recalculateTransforms();
        static if (ignoreParams)
            return globalTransformNoParam_;
        else
            return globalTransform_;
    }

    /**
        Whether transformation is locked to the root node.
    */
    @property bool lockToRoot() @nogc nothrow pure => lockToRoot_;
    @property void lockToRoot(bool value) @nogc {
        if (value && !lockToRoot_) {
            localTransform_.base.translation = this.transformNoLock.translation;
        } else if (!value && lockToRoot_) {
            localTransform_.base.translation = localTransform_.base.translation - parent.transformNoLock.translation;
        }

        lockToRoot_ = value;
    }

    /**
        The depth of this node in the node hirearchy
    */
    final @property int depth() {
        int depthV;
        Node parent = this;
        while (parent !is null) {
            depthV++;
            parent = parent.parent;
        }
        return depthV;
    }

    /// Destructor
    ~this() {
        foreach (child; children_) {
            child.release();
        }
        children_.clear();
    }

    /**
        Constructs a new puppet root node.

        Params:
            parent = The puppet this node will belong to.
    */
    this(Puppet parent) @nogc {
        this.puppet_ = parent;
        this.guid_ = inNewGUID();
    }

    /**
        Constructs a new node

        Params:
            parent = The node to parent the new node to.
    */
    this(Node parent = null) @nogc {
        this(inNewGUID(), parent);
    }

    /**
        Constructs a new node with an GUID

        Params:
            guid =      The GUID to apply to the node.
            parent =    The node to parent the new node to.
    */
    this(GUID guid, Node parent = null) @nogc {
        this.parent = parent;
        this.guid_ = guid;
    }

    /**
        Notifies this node and its children that the transform 
        has changed.
    */
    final void notifyTransformChanged() @nogc nothrow {
        recalculateTransform_ = true;
        foreach (child; children) {
            child.notifyTransformChanged();
        }
    }

    /**
        Calculates the relative position between 2 nodes and applies the offset.
        You should call this before reparenting nodes.

        Params:
            to = The node to set this node relative to.
    */
    void setRelativeTo(Node to) {
        setRelativeTo(to.transformNoLock.matrix);
        this.localZSort = this.localZSort - to.localZSort;
    }

    /**
        Calculates the relative position between this node and a matrix and applies the offset.
        This does not handle zSorting. Pass a Node for that.

        Params:
            to = The matrix to set this node's transform relative to.
    */
    void setRelativeTo(mat4 to) {
        localTransform_.base.translation = to.relativeVectorTo(transformNoLock.matrix);
        localTransform_.base.update();
    }

    /**
        Removes all children from this node
    */
    final void clearChildren() {
        foreach (child; children_) {
            child.parent_ = null;
        }
        this.children_.clear();
    }

    /**
        Adds a node as a child of this node.
    */
    final void addChild(Node child) {
        child.parent = this;
    }

    /**
        Finds this node within its parent node.

        Returns:
            A positive value if this node was found,
            otherwise $(D -1).
    */
    final ptrdiff_t getIndexInParent() {
        return this.getIndexInNode(parent_);
    }

    /**
        Finds this node within the given node.

        Params:
            node = The node to look within

        Returns:
            A positive value if this node was found,
            otherwise $(D -1).
    */
    final ptrdiff_t getIndexInNode(Node node) {
        if (node) {
            foreach (i, ref child; node.children_) {
                if (child is this)
                    return i;
            }
        }
        return -1;
    }

    enum OFFSET_START = size_t.min;
    enum OFFSET_END = size_t.max;
    final void insertInto(Node node, size_t offset) @nogc {
        nodePath_ = null;

        // Remove ourselves from our current parent if we are
        // the child of one already.
        if (parent_ !is null) {
            parent_.children_.remove(this);
            parent_.release();
        }

        // If we want to become parentless we need to handle that
        // seperately, as null parents have no children to update
        if (node is null) {
            this.parent_ = null;
            return;
        }

        // Update our relationship with our new parent
        this.parent_ = node;
        this.parent_.retain();

        // Update position
        if (offset == OFFSET_START) {
            this.parent_.children_.insert(this, 0);
        } else if (offset == OFFSET_END || offset >= parent_.children_.length) {
            this.parent_.children_ ~= this;
        } else {
            this.parent_.children_.insert(this, offset);
        }
        if (this.puppet !is null)
            assumeNoThrowNoGC((Puppet puppet) { puppet.rescanNodes(); }, puppet);
    }

    /**
        Gets whether nodes can be reparented
    */
    bool canReparent(Node to) {
        Node tmp = to;
        while (tmp !is null) {
            if (tmp.guid == this.guid)
                return false;

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
        insertInto(parent, cast(size_t)pOffset);
    }

    /**
        Applies an offset to the Node's transform.

        Params:
            other = The transform to offset the current global transform by.
    */
    void offsetTransform(Transform other) @nogc {
        globalTransform_ = globalTransform_ + other;
        globalTransform_.update();
    }

    /**
        Serializes this node to a DataNode.

        Params:
            recursive = Whether to recurse through children.
    */
    final DataNode serialize(bool recursive = true) @nogc {
        auto result = DataNode.createObject();
        this.onSerialize(result, recursive);
        return result;
    }

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
            recursive = Whether to recurse through children.
    */
    final void serialize(ref DataNode object, bool recursive = true) @nogc {
        this.onSerialize(object, recursive);
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object = The DataNode to deserialize from.
    */
    final void deserialize(ref DataNode object) @nogc {
        this.onDeserialize(object);
    }

    /**
        Finalizes this node and its children.
    */
    final void finalize() @nogc {
        this.onFinalize();
    }

    /**
        Runs a pre-update cycle for this node and its enabled children.

        Params:
            drawList =  The drawlist for the active scene.

        Note:
            This is generally called by the puppet and shouldn't be called
            by you outside of circumstances where the puppet isn't
            controlling rendering.
    */
    final void preUpdate(DrawList drawList) @nogc {
        if (!enabled)
            return;

        localTransform_.offset.clear();
        zSort_.offset = 0;

        this.onPreUpdate(drawList);
        foreach (child; children_) {
            child.preUpdate(drawList);
        }
    }

    /**
        Updates the node

        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.

        Note:
            This is generally called by the puppet and shouldn't be called
            by you outside of circumstances where the puppet isn't
            controlling rendering.
    */
    final void update(float delta, DrawList drawList) @nogc {
        if (!enabled)
            return;

        this.onUpdate(delta, drawList);
        foreach (child; children) {
            child.update(delta, drawList);
        }
    }

    /**
        Update sequence run after the main update sequence.

        Params:
            drawList =  The drawlist for the active scene.

        Note:
            This is generally called by the puppet and shouldn't be called
            by you outside of circumstances where the puppet isn't
            controlling rendering.
    */
    final void postUpdate(DrawList drawList) @nogc {
        if (!enabled)
            return;

        this.onPostUpdate(drawList);
        foreach (child; children_) {
            child.postUpdate(drawList);
        }
    }

    /**
        Draws this node and it's subnodes
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.

        Note:
            This is generally called by the puppet and shouldn't be called
            by you outside of circumstances where the puppet isn't
            controlling rendering.
    */
    final void draw(float delta, DrawList drawList) @nogc {
        this.onDraw(delta, drawList, MaskingMode.none);
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
    bool hasProperty(string key) const @nogc nothrow {
        switch (key) {
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
        Gets the value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The floating point value of the property.
    */
    float getProperty(string key) const @nogc nothrow {
        switch (key) {
        case "zSort":
            return zSort_.offset;
        case "transform.t.x":
            return localTransform_.offset.translation.x;
        case "transform.t.y":
            return localTransform_.offset.translation.y;
        case "transform.t.z":
            return localTransform_.offset.translation.z;
        case "transform.r.x":
            return localTransform_.offset.rotation.x;
        case "transform.r.y":
            return localTransform_.offset.rotation.y;
        case "transform.r.z":
            return localTransform_.offset.rotation.z;
        case "transform.s.x":
            return localTransform_.offset.scale.x;
        case "transform.s.y":
            return localTransform_.offset.scale.y;
        default:
            return 0;
        }
    }

    /**
        Gets the default value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The default value of the property.
    */
    float getPropertyDefault(string key) const @nogc nothrow {
        switch (key) {
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
            return 0;
        }
    }

    /**
        Sets the value of the property.

        Params:
            key =   The name of the property.
            value = The value to set the property to.
    */
    void setProperty(string key, float value) @nogc nothrow {
        switch (key) {
        case "zSort":
            zSort_.offset += value;
            return;
        case "transform.t.x":
            localTransform_.offset.translation.x += value;
            this.notifyTransformChanged();
            return;
        case "transform.t.y":
            localTransform_.offset.translation.y += value;
            this.notifyTransformChanged();
            return;
        case "transform.t.z":
            localTransform_.offset.translation.z += value;
            this.notifyTransformChanged();
            return;
        case "transform.r.x":
            localTransform_.offset.rotation.x += value;
            this.notifyTransformChanged();
            return;
        case "transform.r.y":
            localTransform_.offset.rotation.y += value;
            this.notifyTransformChanged();
            return;
        case "transform.r.z":
            localTransform_.offset.rotation.z += value;
            this.notifyTransformChanged();
            return;
        case "transform.s.x":
            localTransform_.offset.scale.x *= value;
            this.notifyTransformChanged();
            return;
        case "transform.s.y":
            localTransform_.offset.scale.y *= value;
            this.notifyTransformChanged();
            return;
        default:
            return;
        }
    }

    /**
        Gets the string representation of this object.
    */
    override
    string toString() const {
        return name[];
    }
}

mixin Register!(Node, in_node_registry);

/**
    Finds all nodes of the given type (and subtypes) in the node tree.

    Params:
        root =  The root node to start searching from.
        list =  The list to write the results to.
*/
void findNodes(T)(Node root, ref T[] list) @nogc if (is(T : Node)) {
    static void findNodesImpl(Node node, ref T[] list) @nogc {
        if (!node)
            return;

        if (auto found = cast(T)node) {
            list = list.nu_resize(list.length + 1);
            list[$ - 1] = found;
        }

        // Non-part nodes just need to be recursed through,
        // they don't draw anything.
        foreach (child; node.children) {
            findNodesImpl(child, list);
        }
    }

    nu_cleara(list);
    findNodesImpl(root, list);
}

/**
    Sorts a slice of visuals in-place.

    Params:
        slice = The slice to sort.
*/
void sortNodes(T)(ref T[] slice) @nogc nothrow if (is(T : Node)) {
    import nulib.math.fixed : fixed32;
    import numem.sorting : nu_sort;

    // HACK:    nulib doesn't have a float cmp function yet,
    //          as such we convert sorting values to fixed.
    nu_sort!((Visual a, Visual b) @nogc => fixed32(a.zSort).data < fixed32(b.zSort).data)(slice);
}
