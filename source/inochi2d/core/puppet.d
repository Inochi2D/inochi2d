module inochi2d.core.puppet;
import inochi2d.core.node;
import inochi2d.core.nodes;
import inochi2d.math;
import std.algorithm.sorting;

/**
    A puppet
*/
class Puppet {
private:
    /**
        An internal puppet root node
    */
    Node puppetRootNode;

    /**
        A list of parts that are not masked by other parts

        for Z sorting
    */
    Part[] rootParts;

    void scanPartsRecurse(Node node) {
        
        // If we have a part do the main check
        if (Part part = cast(Part)node) {
            if (part.maskingMode != MaskingMode.NoMask) {

                // We've found a root masked part
                rootParts ~= part;
            } else {

                // We've found a root no-masking part
                rootParts ~= part;
                foreach(child; part.children) {
                    scanPartsRecurse(child);
                }
            }
        } else {
            foreach(child; node.children) {
                scanPartsRecurse(child);
            }
        }
    }

    void scanParts(Node node) {

        // We want rootParts to be cleared so that we
        // don't draw the same part multiple times
        // and if the node tree changed we want to reflect those changes
        // not the old node tree.
        rootParts = [];

        this.scanPartsRecurse(node);

        // To make sure the GC can collect any nodes that aren't referenced
        // anymore, we clear its children first, then assign its new child
        // to our "new" root node. In some cases the root node will be
        // quite different.
        if (puppetRootNode !is null) puppetRootNode.clearChildren();
        node.parent = puppetRootNode;
    }

    void selfSort() {
        import std.math : cmp;
        sort!((a, b) => cmp(
            a.parent.localTransform.translation.z, 
            b.parent.localTransform.translation.z) > 0)(rootParts);
    }

public:
    /**
        The root node of the puppet
    */
    Node root;

    /**
        Creates a new puppet from a node tree
    */
    this(Node root) {
        this.puppetRootNode = new Node();
        this.root = root;
        this.scanParts(this.root);
        this.selfSort();
    }

    /**
        Draws the puppet
    */
    final void draw() {
        this.selfSort();

        foreach(rootPart; rootParts) {
            if (rootPart.maskingMode != MaskingMode.NoMask) {
                rootPart.draw();
            } else {
                rootPart.drawOne();
            }
        }
    }

    /**
        Gets this puppet's root transform
    */
    final Transform transform() {
        return puppetRootNode.transform;
    }

    /**
        Rescans the puppet's nodes

        Run this every time you change the layout of the puppet's node tree
    */
    final void rescanNodes() {
        this.scanParts(root);
    }
}