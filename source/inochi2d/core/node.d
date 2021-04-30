module inochi2d.core.node;
import inochi2d.math;

public import inochi2d.core.nodes;

/**
    A node in the Inochi2D rendering tree
*/
class Node {
private:
    Node parent_;
    Node[] children_;

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
        Constructs a new node
    */
    this(Node parent = null) {
        this.parent = parent;
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
        Removes all children from this node
    */
    final void clearChildren() {
        foreach(child; children_) {
            child.parent_ = null;
        }
        this.children_ = [];
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
        Forces this node to be drawn.
    */
    final void forceDrawOne() {
        
        // If we're already enabled no need to force anything
        if (enabled) {
            drawOne();
            return;
        }

        enabled = !enabled;
        drawOne();
        enabled = !enabled;
    }

    override
    string toString() {
        return name;
    }
}