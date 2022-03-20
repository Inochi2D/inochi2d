/*
    Inochi2D Node

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes;
import inochi2d.math;
import inochi2d.core.puppet;
import inochi2d.fmt.serialize;
import inochi2d.math.serialization;
import inochi2d.core.dbg;

public import inochi2d.core.nodes.part;
public import inochi2d.core.nodes.mask;
public import inochi2d.core.nodes.pathdeform;
public import inochi2d.core.nodes.drawable;
//public import inochi2d.core.nodes.shapes; // This isn't mainline yet!

import std.exception;

private {
    uint[] takenUUIDs;
}

package(inochi2d) {
    void inInitNodes() {
        inRegisterNodeType!Node;
    }
}

/**
    Creates a new UUID for a node
*/
uint inCreateUUID() {
    import std.algorithm.searching : canFind;
    import std.random : uniform;

    uint id = uniform!uint();
    while (takenUUIDs.canFind(id)) { id = uniform!uint(); } // Make sure the ID is actually unique in the current context

    return id;
}

/**
    Unloads a single UUID from the internal listing, freeing it up for reuse
*/
void inUnloadUUID(uint id) {
    import std.algorithm.searching : countUntil;
    import std.algorithm.mutation : remove;
    ptrdiff_t idx = takenUUIDs.countUntil(id);
    if (idx != -1) takenUUIDs.remove(idx);
}

/**
    Clears all UUIDs from the internal listing
*/
void inClearUUIDs() {
    takenUUIDs.length = 0;
}

/**
    A node in the Inochi2D rendering tree
*/
@TypeId("Node")
class Node : ISerializable {
private:
    this() { }

    @Ignore
    Puppet puppet_;

    @Ignore
    Node parent_;
    
    @Ignore
    Node[] children_;
    
    @Ignore
    uint uuid_;
    
    @Name("zsort")
    float zsort_ = 0;

    @Name("lockToRoot")
    bool lockToRoot_;

protected:

    // Send mask reset request one node up
    void resetMask() {
        if (parent !is null) parent.resetMask();
    }

    void serializeSelf(ref InochiSerializer serializer) {
        
        serializer.putKey("uuid");
        serializer.putValue(uuid);
        
        serializer.putKey("name");
        serializer.putValue(name);
        
        serializer.putKey("type");
        serializer.putValue(typeId);
        
        serializer.putKey("enabled");
        serializer.putValue(enabled);
        
        serializer.putKey("zsort");
        serializer.putValue(zsort_);
        
        serializer.putKey("transform");
        serializer.serializeValue(this.localTransform);
        
        serializer.putKey("lockToRoot");
        serializer.serializeValue(this.lockToRoot_);
        
        if (children.length > 0) {
            serializer.putKey("children");
            auto childArray = serializer.arrayBegin();
            foreach(child; children) {
                serializer.elemBegin;
                serializer.serializeValue(child);
            }
            serializer.arrayEnd(childArray);
        }
    }

    void serializeSelf(ref InochiSerializerCompact serializer) {
        serializer.putKey("uuid");
        serializer.putValue(uuid);
        
        serializer.putKey("name");
        serializer.putValue(name);
        
        serializer.putKey("type");
        serializer.putValue(typeId);
        
        serializer.putKey("enabled");
        serializer.putValue(enabled);
        
        serializer.putKey("zsort");
        serializer.putValue(zsort_);
        
        serializer.putKey("transform");
        serializer.serializeValue(this.localTransform);
        
        serializer.putKey("lockToRoot");
        serializer.serializeValue(this.lockToRoot_);
        
        if (children.length > 0) {
            serializer.putKey("children");
            auto childArray = serializer.arrayBegin();
            foreach(child; children) {
                serializer.elemBegin;
                serializer.serializeValue(child);
            }
            serializer.arrayEnd(childArray);
        }
    }

package(inochi2d):

    /**
        Needed for deserialization
    */
    void setPuppet(Puppet puppet) {
        this.puppet_ = puppet;
    }

public:

    /**
        Whether the node is enabled
    */
    bool enabled = true;

    /**
        Whether the node is enabled for rendering

        Disabled nodes will not be drawn.

        This happens recursively
    */
    bool renderEnabled() {
        if (parent) return !parent.renderEnabled ? false : enabled;
        return enabled;
    }

    /**
        Visual name of the node
    */
    string name = "Unnamed Node";

    /**
        Returns the unique identifier for this node
    */
    uint uuid() {
        return uuid_;
    }

    /**
        This node's type ID
    */
    string typeId() { return "Node"; }

    /**
        Gets the relative Z sorting
    */
    float relZSort() {
        return zsort_;
    }

    /**
        Gets the Z sorting
    */
    float zSort() {
        return parent !is null ? parent.zSort() + zsort_ : zsort_;
    }

    /**
        Sets the (relative) Z sorting
    */
    void zSort(float value) {
        zsort_ = value;
    }

    /**
        Lock translation to root
    */
    ref bool lockToRoot() {
        return lockToRoot_;
    }

    /**
        Lock translation to root
    */
    void lockToRoot(bool value) {
        
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
        puppet_ = puppet;
    }

    /**
        Constructs a new node
    */
    this(Node parent = null) {
        this(inCreateUUID(), parent);
    }

    /**
        Constructs a new node with an UUID
    */
    this(uint uuid, Node parent = null) {
        this.parent = parent;
        this.uuid_ = uuid;
    }

    /**
        The local transform of the node
    */
    Transform localTransform;

    /**
        The transform in world space
    */
    @Ignore
    Transform transform() {
        localTransform.update();
        
        if (lockToRoot_) return localTransform * puppet.root.localTransform;
        if (parent !is null) return localTransform * parent.transform();
        return localTransform;
    }

    /**
        The transform in world space without locking
    */
    @Ignore
    Transform transformNoLock() {
        localTransform.update();
        
        if (parent !is null) return localTransform * parent.transform();
        return localTransform;
    }

    /**
        Gets a list of this node's children
    */
    final Node[] children() {
        return children_;
    }

    /**
        Gets the parent of this node
    */
    final Node parent() {
        return parent_;
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

    /**
        Sets the parent of this node
    */
    final void parent(Node node) {
        this.insert(node, OFFSET_END);
    }

    enum OFFSET_START = size_t.min;
    enum OFFSET_END = size_t.max;
    final void insert(Node node, size_t offset) {
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
            this.parent_.children_ = this.parent_.children_[0..offset] ~ this ~ this.parent_.children_[offset+1..$-1];
        }
        if (this.puppet !is null) this.puppet.rescanNodes();
    }

    /**
        Draws this node and it's subnodes
    */
    void draw() {
        if (!renderEnabled) return;

        foreach(child; children) {
            child.draw();
        }
    }

    /**
        Draws this node.
    */
    void drawOne() { }


    /**
        Finalizes this node and any children
    */
    void finalize() {
        foreach(child; children) {
            child.finalize();
        }
    }

    /**
        Updates the node
    */
    void update() {
        if (!enabled) return;

        foreach(child; children) {
            child.update();
        }
    }

    override
    string toString() {
        return name;
    }

    /**
        Allows serializing a node (with pretty serializer)
    */
    void serialize(S)(ref S serializer) {
        auto state = serializer.objectBegin();
            this.serializeSelf(serializer);
        serializer.objectEnd(state);
    }

    /**
        Deserializes node from Asdf formatted JSON data.
    */
    SerdeException deserializeFromAsdf(Asdf data) {

        if (auto exc = data["uuid"].deserializeValue(this.uuid_)) return exc;

        if (!data["name"].isEmpty) {
            if (auto exc = data["name"].deserializeValue(this.name)) return exc;
        }

        if (auto exc = data["enabled"].deserializeValue(this.enabled)) return exc;

        if (auto exc = data["zsort"].deserializeValue(this.zsort_)) return exc;
        
        if (auto exc = data["transform"].deserializeValue(this.localTransform)) return exc;
        
        if (!data["lockToRoot"].isEmpty) {
            if (auto exc = data["lockToRoot"].deserializeValue(this.lockToRoot_)) return exc;
        }

        // Pre-populate our children with the correct types
        foreach(child; data["children"].byElement) {
            
            // Fetch type from json
            string type;
            if (auto exc = child["type"].deserializeValue(type)) return exc;
            
            // Skips unknown node types
            // TODO: A logging system that shows a warning for this?
            if (!inHasNodeType(type)) continue;

            // instantiate it
            Node n = inInstantiateNode(type, this);
            if (auto exc = child.deserializeValue(n)) return exc;
        }


        return null;
    }

    /**
        Force sets the node's ID

        THIS IS NOT A SAFE OPERATION.
    */
    final void forceSetUUID(uint uuid) {
        this.uuid_ = uuid;
    }

    /**
        Gets the combined bounds of the node
    */
    vec4 getCombinedBounds() {
        auto tr = transform;
        vec4 combined = vec4(tr.translation.x, tr.translation.y, tr.translation.x, tr.translation.y);
        
        // Get Bounds as drawable
        if (Drawable drawable = cast(Drawable)this) {
            combined = drawable.bounds;
        }

        foreach(child; children) {
            vec4 cbounds = child.getCombinedBounds();
            if (cbounds.x < combined.x) combined.x = cbounds.x;
            if (cbounds.y < combined.y) combined.y = cbounds.y;
            if (cbounds.z > combined.z) combined.z = cbounds.z;
            if (cbounds.w > combined.w) combined.w = cbounds.w;
        }

        return combined;
    }

    /**
        Gets whether nodes can be reparented
    */
    bool canReparent(Node to) {
        Node tmp = to;
        while(tmp !is null) {
            if (tmp.uuid == this.uuid) return false;
            
            // Check next up
            tmp = tmp.parent;
        }
        return true;
    }

    /**
        Draws orientation of the node
    */
    void drawOrientation() {
        auto trans = transform.matrix();
        inDbgLineWidth(4);

        // X
        inDbgSetBuffer([vec3(0, 0, 0), vec3(32, 0, 0)], [0, 1]);
        inDbgDrawLines(vec4(1, 0, 0, 0.7), trans);

        // Y
        inDbgSetBuffer([vec3(0, 0, 0), vec3(0, -32, 0)], [0, 1]);
        inDbgDrawLines(vec4(0, 1, 0, 0.7), trans);
        
        // Z
        inDbgSetBuffer([vec3(0, 0, 0), vec3(0, 0, -32)], [0, 1]);
        inDbgDrawLines(vec4(0, 0, 1, 0.7), trans);

        inDbgLineWidth(1);
    }

    /**
        Draws bounds
    */
    void drawBounds() {
        vec4 bounds = this.getCombinedBounds;

        float width = bounds.z-bounds.x;
        float height = bounds.w-bounds.y;
        inDbgSetBuffer([
            vec3(bounds.x, bounds.y, 0),
            vec3(bounds.x + width, bounds.y, 0),
            
            vec3(bounds.x + width, bounds.y, 0),
            vec3(bounds.x + width, bounds.y+height, 0),
            
            vec3(bounds.x + width, bounds.y+height, 0),
            vec3(bounds.x, bounds.y+height, 0),
            
            vec3(bounds.x, bounds.y+height, 0),
            vec3(bounds.x, bounds.y, 0),
        ]);
        inDbgLineWidth(3);
        inDbgDrawLines(vec4(.5, .5, .5, 1));
        inDbgLineWidth(1);
    }
}

//
//  SERIALIZATION SHENNANIGANS
//

struct TypeId { string id; }

private {
    Node delegate(Node parent)[string] typeFactories;

    Node inInstantiateNode(string id, Node parent = null) {
        return typeFactories[id](parent);
    }
}

void inRegisterNodeType(T)() if (is(T : Node)) {
    import std.traits : getUDAs;
    typeFactories[getUDAs!(T, TypeId)[0].id] = (Node parent) {
        return new T(parent);
    };
}

/**
    Gets whether a node type is present in the factories
*/
bool inHasNodeType(string id) {
    return (id in typeFactories) !is null;
}

mixin template InNode(T) {
    static this() {
        inRegisterNodeType!(T);
    }
}