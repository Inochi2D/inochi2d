module inochi2d.core.puppet;
import inochi2d.fmt.serialize;
import inochi2d.core;
import inochi2d.math;
import std.algorithm.sorting;
import std.exception;
import std.format;
import std.file;
import std.path : extension;
import std.json;

/**
    Magic value meaning that the model has no thumbnail
*/
enum NO_THUMBNAIL = uint.max;

/**
    Puppet meta information
*/
struct PuppetMeta {

    /**
        Name of the puppet
    */
    string name;
    /**
        Version of the Inochi2D spec that was used for creating this model
    */
    @Name("version")
    string version_ = "1.0-alpha";

    /**
        Authors of the puppet
    */
    string[] authors;

    /**
        Copyright string
    */
    @Optional
    string copyright;

    /**
        Contact information of the first author
    */
    @Optional
    string contact;

    /**
        Link to the origin of this puppet
    */
    @Optional
    string reference;

    /**
        Texture ID of this puppet's thumbnail
    */
    @Optional
    @Name("thumbnail_id")
    uint thumbnailId = NO_THUMBNAIL;
}

/**
    A puppet
*/
class Puppet {
private:
    /**
        An internal puppet root node
    */
    @Ignore
    Node puppetRootNode;

    /**
        A list of parts that are not masked by other parts

        for Z sorting
    */
    @Ignore
    Part[] rootParts;

    void scanPartsRecurse(ref Node node) {

        // Don't need to scan null nodes
        if (node is null) return;

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

    final void scanParts(bool reparent = false)(ref Node node) {

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
        static if (reparent) { 
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

    Node findNode(Node n, string name) {

        // Name matches!
        if (n.name == name) return n;

        // Recurse through children
        foreach(child; n.children) {
            if (Node c = findNode(child, name)) return c;
        }

        // Not found
        return null;
    }

    Node findNode(Node n, uint uuid) {

        // Name matches!
        if (n.uuid == uuid) return n;

        // Recurse through children
        foreach(child; n.children) {
            if (Node c = findNode(child, uuid)) return c;
        }

        // Not found
        return null;
    }

public:
    /**
        Meta information about this puppet
    */
    @Name("meta")
    PuppetMeta meta;

    /**
        The root node of the puppet
    */
    @Name("nodes", "Root Node")
    Node root;

    /**
        Parameters
    */
    @Name("param", "Parameters")
    @Optional
    Parameter[] parameters;

    /**
        INP Texture slots for this puppet
    */
    @Ignore
    Texture[] textureSlots;

    /**
        Extended vendor data
    */
    @Ignore
    JSONValue[string] extData;

    /**
        Creates a new puppet from nothing ()
    */
    this() { 
        this.puppetRootNode = new Node(this); 
        root = new Node(this.puppetRootNode); 
        root.name = "Root";
    }

    /**
        Creates a new puppet from a node tree
    */
    this(Node root) {
        this.root = root;
        this.puppetRootNode = new Node(this);
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
            if (!rootPart.renderEnabled) continue;
            rootPart.drawOne();
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
        this.scanParts!false(root);
    }

    /**
        Finds Node by its name
    */
    T find(T = Node)(string name) if (is(T : Node)) {
        return cast(T)findNode(root, name);
    }

    /**
        Finds Node by its unique id
    */
    T find(T = Node)(uint uuid) if (is(T : Node)) {
        return cast(T)findNode(root, uuid);
    }

    /**
        Returns all the parts in the puppet
    */
    Part[] getAllParts() {
        Part[] parts;

        void partScanRecurse(Node n) {
            if (Part pn = cast(Part)n) {
                parts ~= pn;
            }

            foreach(child; n.children) {
                partScanRecurse(child);
            }
        }

        return parts;
    }

    /**
        Finds nodes based on their type
    */
    final T[] findNodesType(T)(Node n) if (is(T : Node)) {
        T[] nodes;

        if (T item = cast(T)n) {
            nodes ~= item;
        }

        // Recurse through children
        foreach(child; n.children) {
            nodes ~= findNodesType!T(child);
        }

        return nodes;
    }

    /**
        Adds a texture to a new slot if it doesn't already exist within this puppet
    */
    final uint addTextureToSlot(Texture texture) {
        import std.algorithm.searching : canFind;

        // Add texture if we can't find it.
        if (!textureSlots.canFind(texture)) textureSlots ~= texture;
        return cast(uint)textureSlots.length-1;
    }

    /**
        Populate texture slots with all visible textures in the model
    */
    final void populateTextureSlots() {
        if (textureSlots.length > 0) textureSlots.length = 0;
        
        foreach(part; rootParts) {
            foreach(texture; part.textures) {
                this.addTextureToSlot(texture);
            }
        }
    }

    /**
        Sets thumbnail of this puppet
    */
    final void setThumbnail(Texture texture) {
        if (this.meta.thumbnailId == NO_THUMBNAIL) {
            this.meta.thumbnailId = this.addTextureToSlot(texture);
        } else {
            textureSlots[this.meta.thumbnailId] = texture;
        }
    }

    /**
        Gets the texture slot index for a texture

        returns -1 if none was found
    */
    final ptrdiff_t getTextureSlotIndexFor(Texture texture) {
        import std.algorithm.searching : countUntil;
        return textureSlots.countUntil(texture);
    }

    /**
        Clears this puppet's thumbnail

        By default it does not delete the texture assigned, pass in true to delete texture
    */
    final void clearThumbnail(bool deleteTexture = false) {
        import std.algorithm.mutation : remove;
        if (deleteTexture) textureSlots = remove(textureSlots, this.meta.thumbnailId);
        this.meta.thumbnailId = NO_THUMBNAIL;
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

            string s = "%s[%s] %s <%s>\n".format(n.children.length > 0 ? "╭─" : "", n.typeId, n.name, n.uuid);
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

    /**
        Finalizer
    */
    void finalizeDeserialization(Asdf data) {
        this.root.setPuppet(this);
        this.root.name = "Root";
        this.puppetRootNode = new Node(this);
        this.scanParts!true(this.root);
        this.selfSort();
        this.root.finalize();
        foreach(parameter; parameters) {
            parameter.finalize(this);
        }
    }

    /**
        Gets the internal root parts array
    */
    final Part[] getRootParts() {
        return rootParts;
    }
}