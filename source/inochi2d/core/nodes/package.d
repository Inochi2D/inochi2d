/*
    Inochi2D Node

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes;
import inochi2d.math;
import inochi2d.core.puppet;

public import inochi2d.core.nodes.part;
public import inochi2d.core.nodes.mask;
public import inochi2d.core.nodes.pathdeform;
public import inochi2d.core.nodes.drawable;

private {
    uint[] takenUUIDs;
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
class Node {
private:
    Puppet puppet_;
    Node parent_;
    Node[] children_;
    uint uuid_;
    float zsort_ = 0;

protected:

    // Send mask reset request one node up
    void resetMask() {
        if (parent !is null) parent.resetMask();
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
            parent_.children_.remove(idx);
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
}