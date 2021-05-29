module inochi2d.core.puppet;
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

        // Don't count disabled parts
        if (!node.enabled) return;

        // If we have a part do the main check
        if (Part part = cast(Part)node) {
            rootParts ~= part;
            foreach(child; part.children) {
                scanPartsRecurse(child);
            }
            
        } else {

            // Non-part nodes just need to be recursed through,
            // they don't draw anything.
            foreach(child; node.children) {
                scanPartsRecurse(child);
            }
        }
    }

    final void scanParts(bool reparent = false)(Node node) {

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
        if (reparent) { 
            if (puppetRootNode !is null) puppetRootNode.clearChildren();
            node.parent = puppetRootNode;
        }
    }

    void selfSort() {
        import std.math : cmp;
        sort!((a, b) => cmp(
            a.zSort, 
            b.zSort) > 0)(rootParts);
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
        this.puppetRootNode = new Node(this);
        this.root = root;
        this.root.name = "Root";
        this.scanParts!true(this.root);
        this.selfSort();
    }

    /**
        Updates the nodes
    */
    final void update() {
        root.update();
    }

    /**
        Draws the puppet
    */
    final void draw() {
        this.selfSort();

        foreach(rootPart; rootParts) {
            rootPart.drawOne();
        }
    }

    /**
        Draws the puppet's outlines for every drawable
    */
    final void drawOutlines() {
        root.drawOutline();
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
        this.scanParts!false(root);
    }

    /**
        This cursed toString implementation outputs the puppet's
        nodetree as a pretty printed tree.

        Please use a graphical viewer instead of this if you can,
        eg. Inochi Creator.
    */
    override
    string toString() {
        import std.format : format;
        import std.range : repeat, takeExactly;
        import std.array : array;
        bool[] lineSet;

        string toStringBranch(Node n, int indent, bool showLines = true) {

            lineSet ~= n.children.length > 0;
            string getLineSet() {
                if (indent == 0) return "";
                string s = "";
                foreach(i; 1..lineSet.length) {
                    s ~= lineSet[i-1] ? "│ " : "  ";
                }
                return s;
            }

            string iden = getLineSet();

            string s = "%s%s <%s>\n".format(n.children.length > 0 ? "╭─" : "", n.name, n.uuid);
            foreach(i, child; n.children) {
                string term = "├→";
                if (i == n.children.length-1) {
                    term = "╰→";
                    lineSet[indent] = false;
                }
                s ~= "%s%s%s".format(iden, term, toStringBranch(child, indent+1));
            }

            lineSet.length--;

            return s;
        }

        return toStringBranch(root, 0);
    }
}