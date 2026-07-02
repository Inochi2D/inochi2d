/**
    Inochi2D Node

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.nodes;
import inochi2d.core.serde;
import inochi2d.core.math;
import inochi2d.core.guid;
import inochi2d.core;
import inochi2d.common;
import nulib.string;
import numem;
import nulib;

public import inochi2d.puppet;
public import inochi2d.nodes.deformer;
public import inochi2d.nodes.visual;
public import inochi2d.nodes.legacy;
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
@TypeId("Node", IN_MAKE_TAG!(0, 0))
@RegisterFallback
class Node : NuRefCounted, IPropertyOwner, ISerializable, IDeserializable!ModelState {
private:
@nogc:
    Puppet puppet_;
    Node parent_;
    vector!Node children_;
    GUID guid_;
    string nodePath_;
    uint nid_;

    bool lockToRoot_;
    Basis globalMatrix_;
    Basis globalMatrixNoParam_;
    offset_value!Transform localTransform_;
    offset_value!float zSort_;

    // Implementation of the transform update algorithm.
    void transformUpdateImpl() {

        // Set base matrices.
        globalMatrix_ = (localTransform_.base + localTransform_.offset).matrix();
        globalMatrixNoParam_ = localTransform_.base.matrix();

        if (lockToRoot_) {
            globalMatrix_.matrix =          puppet.root.localTransform_.base.matrix() * globalMatrix_;
            globalMatrixNoParam_.matrix =   puppet.root.localTransform_.base.matrix() * globalMatrixNoParam_;
        } else if (parent_ !is null) {
            globalMatrix_ =                 parent_.globalMatrix_ * globalMatrix_;
            globalMatrixNoParam_ =          parent_.globalMatrixNoParam_ * globalMatrixNoParam_;
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
    */
    void onSerialize(ref DataNode object) @nogc { }

    /**
        Deserializes this node from a DataNode.

        Params:
            object =    The DataNode to deserialize from.
            state =     The state of the deserializer.
    */
    void onDeserialize(ref DataNode object, ref ModelState state) @nogc { }

    /**
        Called when the node is to finalize its deserialization from disk.

        Params:
            state =     The state of the deserializer.
    */
    void onFinalize(ref ModelState state) @nogc { }

    /**
        Called during the early update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    void onPreUpdate(DrawList drawList) @nogc { }

    /**
        Called during the update phase of a new frame.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
    */
    void onUpdate(float delta, DrawList drawList) @nogc { }

    /**
        Called during the late update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    void onPostUpdate(DrawList drawList) @nogc { }

    /**
        Called when the node is asked to update its transform.
    */
    void onTransformUpdate() @nogc { }

    /**
        Called when the node is to be redrawn.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
    */
    void onDraw(float delta, DrawList drawList) @nogc { }

    /**
        Called when the node is moved from one parent
        to another.

        Params:
            from =  The node that used to be this node's parent.
            to =    The node it was moved to.
            index = The index the node was moved to.
    */
    void onMoved(Node from, Node to, ptrdiff_t index) { }

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
        if (node) {
            node.addChild(this);
        } else if (parent_) {
            parent_.removeChild(this);
        }
    }

    /**
        The index of this node within ints parent.
    */
    final @property ptrdiff_t parentIndex() => parent ? parent.findChild(this) : -1;

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
        The global basis matrix.
    */
    @property Basis matrix() @nogc => globalMatrix_;

    /**
        The global basis matrix with parameter omitted.
    */
    @property Basis baseMatrix() @nogc => globalMatrixNoParam_;

    /**
        The transform in local-space.
    */
    @property ref Transform localTransform() @nogc => localTransform_.base;

    /**
        The offset transform in local-space.
    */
    @property ref Transform localTransformOffset() @nogc => localTransform_.offset;

    /**
        Whether transformation is locked to the root node.
    */
    @property bool lockToRoot() @nogc nothrow pure => lockToRoot_;
    @property void lockToRoot(bool value) @nogc {
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
        this.zSort_.base = 0;
        this.zSort_.offset = 0;
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
        this.zSort_.base = 0;
        this.zSort_.offset = 0;
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
        Gets whether this node can be moved to the 
        given target node.

        Params:
            to = The move destination.

        Returns:
            $(D true) if the node can be moved inside of the given node,
            $(D false) otherwise.
    */
    final bool canMoveTo(Node to) {
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
        Finds the index of the given direct child node
        within this node.

        Params:
            child = The node to find.

        Returns:
            The index of the node,
            $(D -1) if not found.
    */
    final ptrdiff_t findChild(Node child) {
        return children_.find(child);
    }

    /**
        Removes a given node from this node's children.

        Params:
            child = A direct child to remove.

        Returns:
            $(D true) if the given node was removed,
            $(D false) otherwise.
    */
    final bool removeChild(Node child) {
        auto idx = this.findChild(child);
        if (idx >= 0) {
            child.onMoved(this, null, -1);
            child.release();

            this.children_.removeAt(idx);
            child.parent_ = null;
            return true;
        }
        return false;
    }

    /**
        Adds a node as a child of this node.
    */
    final void addChild(Node child) {
        child.onMoved(child.parent_, this, this.children_.length);
        child.retain();

        // Remove this node from its parent, if needed.
        if (child.parent_) {
            child.parent_.removeChild(child);
        }

        this.children_ ~= child;
        child.parent_ = this;
    }

    /**
        Moves the child to the given offset in this
        node's child list.

        Params:
            child =     The child the move
            to =        The index to move to.
    */
    final void moveChild(Node child, ptrdiff_t to) {
        auto idx = this.findChild(child);
        if (idx >= 0) {
            size_t dst = to < 0 ? children_.length-(abs(to)+1) : to;
            
            // Don't swap with itself.
            if (dst == idx)
                return;

            // Swap if valid.
            if (dst < this.children_.length) {
                child.onMoved(child.parent_, child.parent_, dst);
                nu_swap(this.children_[idx], this.children_[to]);
            }
        }
    }

    /** 
        Set new Parent
    */
    void reparent(Node parent, size_t pOffset) {
        parent.addChild(this);
        parent.moveChild(this, pOffset);
    }

    /**
        Serializes this node to a DataNode.

        Params:
            recursive = Whether to recurse through children.
    */
    final DataNode serialize(bool recursive = true) @nogc {
        auto result = DataNode.createObject();
        this.serialize(result, recursive);
        return result;
    }

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
            recursive = Whether to recurse through children.
    */
    final void serialize(ref DataNode object, bool recursive = true) @nogc {
        nstring guid = guid_.toString();
        object["guid"] = guid[];
        object["name"] = name[];
        object["type"] = typeId.sid;
        object["enabled"] = enabled;
        object["zsort"] = zSort_.base;
        object["transform"] = localTransform_.base.serialize();
        object["lockToRoot"] = lockToRoot_;

        // Call callback and iterate to children.
        this.onSerialize(object);

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
            object =    The DataNode to deserialize from.
            state =     The state of the deserializer.
    */
    final void deserialize(ref DataNode object, ref ModelState state) @nogc {
        this.guid_ = object.tryGetGUID(state, "uuid", "guid");
        object.tryGetRef(state, name, "name");
        object.tryGetRef(state, enabled, "enabled");
        object.tryGetRef(state, zSort_.base, "zsort");
        object.tryGetRef(state, localTransform_.base, "transform");
        object.tryGetRef(state, lockToRoot_, "lockToRoot");

        // Call callback and iterate to children.
        this.onDeserialize(object, state);

        // Pre-populate our children with the correct types
        if ("children" in object && object["children"].isArray) {
            foreach (ref child; object["children"].array) {

                // NOTE:    inInstantiateNode implicitly handles setting the
                //          Parent-child relationship, so we don't need to do
                //          anything else besides pass it onto the child's
                //          deserializer.
                if (Node n = in_node_registry.tryCreateFrom(child)) {
                    n.parent = this;
                    n.deserialize(child, state);
                }
            }
        }
    }

    /**
        Finalizes this node and its children.

        Params:
            state =     The state of the deserializer.
    */
    final void finalize(ref ModelState state) @nogc {
        nid_ = typeId.nid;

        // Call callback and iterate to children.
        this.onFinalize(state);
        foreach(child; this.children_) {
            child.finalize(state);
        }
    }

    /**
        Updates the transform of the node and all nodes underneath it.

        Note:
            Children which have been disabled will not be updated.
    */
    final void updateTransform() @nogc {

        // Do the base algorithm first.
        this.transformUpdateImpl();

        // Then pass on to callback and iterate to children.
        this.onTransformUpdate();
        foreach(child; children_) {
            child.updateTransform();
        }
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
        this.onDraw(delta, drawList);
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
            return;
        case "transform.t.y":
            localTransform_.offset.translation.y += value;
            return;
        case "transform.t.z":
            localTransform_.offset.translation.z += value;
            return;
        case "transform.r.x":
            localTransform_.offset.rotation.x += value;
            return;
        case "transform.r.y":
            localTransform_.offset.rotation.y += value;
            return;
        case "transform.r.z":
            localTransform_.offset.rotation.z += value;
            return;
        case "transform.s.x":
            localTransform_.offset.scale.x *= value;
            return;
        case "transform.s.y":
            localTransform_.offset.scale.y *= value;
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
void sortNodes(T)(T[] slice) @nogc nothrow if (is(T : Node)) {
    import nulib.math.fixed : fixed32;
    import numem.sorting : nu_sort;

    // HACK:    nulib doesn't have a float cmp function yet,
    //          as such we convert sorting values to fixed.
    nu_sort!((a, b) @nogc => fixed32(a.zSort).data > fixed32(b.zSort).data)(slice);
}
