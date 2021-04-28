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

    void scanParts(Node node) {
        
        // If we have a part do the main check
        if (Part part = cast(Part)node) {
            if (part.maskingMode != MaskingMode.NoMask) {

                // We've found a root masked part
                rootParts ~= part;
            } else {

                // We've found a root no-masking part
                rootParts ~= part;
                foreach(child; part.children) {
                    scanParts(child);
                }
            }
        } else {
            foreach(child; node.children) {
                scanParts(child);
            }
        }
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
        this.root = root;
        this.root.parent = puppetRootNode;
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