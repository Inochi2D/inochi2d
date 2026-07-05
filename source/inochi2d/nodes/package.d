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
public import nulib.quark;

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

    // The property store for the node.
    PropertyStore props_;

    bool lockToRoot_;
    Basis globalMatrix_;
    Basis globalMatrixNoParam_;

    Transform localTransform_;

    // Implementation of the transform update algorithm.
    void transformUpdateImpl() {

        // Set base matrices.
        globalMatrix_ = (localTransform_ + localTransformOffset).matrix();
        globalMatrixNoParam_ = localTransform_.matrix();

        if (lockToRoot_) {
            globalMatrix_.matrix = puppet.root.localTransform_.matrix() * globalMatrix_;
            globalMatrixNoParam_.matrix = puppet.root.localTransform_.matrix() * globalMatrixNoParam_;
        } else if (parent_ !is null) {
            globalMatrix_ = parent_.globalMatrix_ * globalMatrix_;
            globalMatrixNoParam_ = parent_.globalMatrixNoParam_ * globalMatrixNoParam_;
        }
    }

    // Define property list
    void defineProperties(ref PropertyStore propList) {
        propList.define!float(PROP_TRANSLATE_X, 0);
        propList.define!float(PROP_TRANSLATE_Y, 0);
        propList.define!float(PROP_TRANSLATE_Z, 0);
        propList.define!float(PROP_ROTATE_X, 0);
        propList.define!float(PROP_ROTATE_Y, 0);
        propList.define!float(PROP_ROTATE_Z, 0);
        propList.define!float(PROP_SCALE_X, 1);
        propList.define!float(PROP_SCALE_Y, 1);

        // Overlays that lets us get the values in bulk.
        propList.defineOverlay!Transform(PROP_TRANSFORM, propList.offsetOf(PROP_TRANSLATE_X));

        this.onDefineProperties(propList);
        propList.resetAll();
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
    void onSerialize(ref DataNode object) @nogc {
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object =    The DataNode to deserialize from.
            state =     The state of the deserializer.
    */
    void onDeserialize(ref DataNode object, ref ModelState state) @nogc {
    }

    /**
        Called when the node is to finalize its deserialization from disk.

        Params:
            state =     The state of the deserializer.
    */
    void onFinalize(ref ModelState state) @nogc {
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
        Called when the node is asked to update its transform.
    */
    void onTransformUpdate() @nogc {
    }

    /**
        Called when the node is to be redrawn.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
    */
    void onDraw(float delta, DrawList drawList) @nogc {
    }

    /**
        Called when the node is moved from one parent
        to another.

        Params:
            from =  The node that used to be this node's parent.
            to =    The node it was moved to.
            index = The index the node was moved to.
    */
    void onMoved(Node from, Node to, ptrdiff_t index) {
    }

    /**
        Called when the node is to define its properties.

        Call $(D propList.define) with a quark to do this.

        Params:
            propList = The property list to populate.
    */
    void onDefineProperties(ref PropertyStore propList) {
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
        The node's property store, should generally not be directly used.
    */
    final @property ref PropertyStore props() @nogc nothrow pure => props_;

    /**
        The transform in local-space.
    */
    @property ref Transform localTransform() @nogc => localTransform_;

    /**
        The offset transform in local-space.
    */
    @property Transform localTransformOffset() @nogc => props_.get!Transform(PROP_TRANSFORM);

    /**
        The global basis matrix.
    */
    @property Basis matrix() @nogc => globalMatrix_;

    /**
        The global basis matrix with parameter omitted.
    */
    @property Basis baseMatrix() @nogc => globalMatrixNoParam_;

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
        this.defineProperties(props_);
        this.guid_ = inNewGUID();
        this.puppet_ = parent;
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
        this.defineProperties(props_);
        this.parent = parent;
        this.guid_ = guid;
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
            size_t dst = to < 0 ? children_.length - (abs(to) + 1) : to;

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
        object["transform"] = localTransform_.serialize();
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
        object.tryGetRef(state, enabled, "enabled");
        object.tryGetRef(state, name, "name");
        object.tryGetRef(state, localTransform_, "transform");
        object.tryGetRef(state, lockToRoot_, "lockToRoot");

        // This ugly hack exists to upgrade legacy masks to the new masks.
        float zsort08;
        if (state.doUpgrade08) {
            if ("zsort" !in state.upctx)
                state.upctx["zsort"] = 0.0;

            object.tryGetRef(state, zsort08, "zsort");
            state.upctx["zsort"] = state.upctx["zsort"] + zsort08;
        }

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

        // This ugly hack exists to upgrade legacy masks to the new masks.
        if (state.doUpgrade08) {
            state.upctx["zsort"] = state.upctx["zsort"] - zsort08;
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
        foreach (child; this.children_) {
            child.finalize(state);
        }
    }

    /**
        Updates the transform of the node and all nodes underneath it.

        Note:
            Children which have been disabled will not be updated.
    */
    final void updateTransform() @nogc {

        // Do the base algorithm first,
        // then pass on to callback and iterate to children.
        this.transformUpdateImpl();
        this.onTransformUpdate();

        foreach (child; children_) {
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
    bool hasProperty(quark key) const @nogc nothrow {
        return props_.offsetOf(key) != -1;
    }

    /**
        Gets the value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The floating point value of the property.
    */
    float getProperty(quark key) const @nogc nothrow {
        return props_.get!float(key);
    }

    /**
        Gets the default value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The default value of the property.
    */
    float getPropertyDefault(quark key) const @nogc nothrow {
        return props_.getDefault!float(key);
    }

    /**
        Sets the value of the property.

        Params:
            key =   The name of the property.
            value = The value to set the property to.
    */
    void setProperty(quark key, float value) @nogc nothrow {
        return props_.set!float(key, value);
    }

    /**
        Resets the given property.

        Params:
            key = The name of the property.
    */
    void resetProperty(quark key) @nogc nothrow {
        props_.reset(key);
    }

    /**
        Resets all properties.
    */
    void resetProperties() @nogc nothrow {
        props_.resetAll();
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
// dfmt off




//
//          TYPES AND REGISTRIES
//

/**
    The public node registry.
*/
__gshared TypeRegistry!Node in_node_registry;




//
//          QUARKS
//

// Register quarks for this file.
mixin RegisterQuarks!();

/**
    A transform
*/
@propkey("transform")
__gshared immutable(quark) PROP_TRANSFORM;

/**
    X translation.
*/
@propkey("transform.t.x")
__gshared immutable(quark) PROP_TRANSLATE_X;

/**
    Y translation.
*/
@propkey("transform.t.y")
__gshared immutable(quark) PROP_TRANSLATE_Y;

/**
    Z translation.
*/
@propkey("transform.t.z")
__gshared immutable(quark) PROP_TRANSLATE_Z;

/**
    X rotation.
*/
@propkey("transform.r.x")
__gshared immutable(quark) PROP_ROTATE_X;

/**
    y rotation.
*/
@propkey("transform.r.y")
__gshared immutable(quark) PROP_ROTATE_Y;

/**
    z rotation.
*/
@propkey("transform.r.z")
__gshared immutable(quark) PROP_ROTATE_Z;

/**
    X scale.
*/
@propkey("transform.s.x")
__gshared immutable(quark) PROP_SCALE_X;

/**
    y scale.
*/
@propkey("transform.s.y")
__gshared immutable(quark) PROP_SCALE_Y;




//
//          HELPER FUNCTIONS
//

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
