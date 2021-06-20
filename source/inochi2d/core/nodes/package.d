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
    while (takenUUIDs.canFind(id)) { uniform!uint(); } // Make sure the ID is actually unique in the current context

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
        Visual name of the node
    */
    string name = "Unnamed Node";

    /**
        Whether the node is enabled

        Disabled nodes will not be drawn.
    */
    bool enabled = true;

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
        
        // TODO: handle calculating world space transform
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
        this.parent_.children_ ~= this;
        if (this.puppet !is null) this.puppet.rescanNodes();
    }

    /**
        Draws this node and it's subnodes
    */
    void draw() {
        if (!enabled) return;

        foreach(child; children) {
            child.draw();
        }
    }

    /**
        Draws this node.
    */
    void drawOne() { }

    /**
        Draws this node outline and its subnodes' outlines
    */
    void drawOutline() {
        this.drawOutlineOne();
        foreach(child; children) {
            child.drawOutline();
        }
    }
    
    /**
        Draws this node outline
    */
    void drawOutlineOne() {
        auto trans = transform.matrix();

        if (inDbgDrawMeshOrientation) {
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
    }

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
    
    SerdeException deserializeFromAsdf(Asdf data) {

        if (auto exc = data["uuid"].deserializeValue(this.uuid_)) return exc;

        if (!data["name"].isEmpty) {
            if (auto exc = data["name"].deserializeValue(this.name)) return exc;
        }

        if (auto exc = data["enabled"].deserializeValue(this.enabled)) return exc;

        if (auto exc = data["zsort"].deserializeValue(this.zsort_)) return exc;
        
        if (auto exc = data["transform"].deserializeValue(this.localTransform)) return exc;

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
        vec4 combined = vec4(0);
        
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