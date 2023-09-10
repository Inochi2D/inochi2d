module inochi2d.core.puppet;
import inochi2d.fmt.serialize;
import inochi2d.core;
import inochi2d.math;
import std.algorithm.sorting;
import std.algorithm.mutation : SwapStrategy;
import std.exception;
import std.format;
import std.file;
import std.path : extension;
import std.json;

/**
    Magic value meaning that the model has no thumbnail
*/
enum NO_THUMBNAIL = uint.max;

enum PuppetAllowedUsers {
    /**
        Only the author(s) are allowed to use the puppet
    */
    OnlyAuthor = "onlyAuthor",

    /**
        Only licensee(s) are allowed to use the puppet
    */
    OnlyLicensee = "onlyLicensee",

    /**
        Everyone may use the model
    */
    Everyone = "everyone"
}

enum PuppetAllowedRedistribution {
    /**
        Redistribution is prohibited
    */
    Prohibited = "prohibited",

    /**
        Redistribution is allowed, but only under
        the same license as the original.
    */
    ViralLicense = "viralLicense",

    /**
        Redistribution is allowed, and the puppet
        may be redistributed under a different
        license than the original.

        This goes in conjunction with modification rights.
    */
    CopyleftLicense = "copyleftLicense"
}

enum PuppetAllowedModification {
    /**
        Modification is prohibited
    */
    Prohibited = "prohibited",

    /**
        Modification is only allowed for personal use
    */
    AllowPersonal = "allowPersonal",

    /**
        Modification is allowed with redistribution,
        see allowedRedistribution for redistribution terms.
    */
    AllowRedistribute = "allowRedistribute",
}

class PuppetUsageRights {
    /**
        Who is allowed to use the puppet?
    */
    @Optional
    PuppetAllowedUsers allowedUsers = PuppetAllowedUsers.OnlyAuthor;

    /**
        Whether violence content is allowed
    */
    @Optional
    bool allowViolence = false;

    /**
        Whether sexual content is allowed
    */
    @Optional
    bool allowSexual = false;

    /**
        Whether commerical use is allowed
    */
    @Optional
    bool allowCommercial = false;

    /**
        Whether a model may be redistributed
    */
    @Optional
    PuppetAllowedRedistribution allowRedistribution = PuppetAllowedRedistribution.Prohibited;

    /**
        Whether a model may be modified
    */
    @Optional
    PuppetAllowedModification allowModification = PuppetAllowedModification.Prohibited;

    /**
        Whether the author(s) must be attributed for use.
    */
    @Optional
    bool requireAttribution = false;
}

/**
    Puppet meta information
*/
class PuppetMeta {

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
        Rigger(s) of the puppet
    */
    @Optional
    string rigger;

    /**
        Artist(s) of the puppet
    */
    @Optional
    string artist;

    /**
        Usage Rights of the puppet
    */
    @Optional
    PuppetUsageRights rights;

    /**
        Copyright string
    */
    @Optional
    string copyright;

    /**
        URL of license
    */
    @Optional
    string licenseURL;

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
    uint thumbnailId = NO_THUMBNAIL;

    /**
        Whether the puppet should preserve pixel borders.
        This feature is mainly useful for puppets which use pixel art.
    */
    @Optional
    bool preservePixels = false;
}

/**
    Puppet physics settings
*/
class PuppetPhysics {
    @Optional
    float pixelsPerMeter = 1000;

    @Optional
    float gravity = 9.8;
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
    Node[] rootParts;

    /**
        A list of drivers that need to run to update the puppet
    */
    Driver[] drivers;

    /**
        A list of parameters that are driven by drivers
    */
    Driver[Parameter] drivenParameters;

    /**
        A dictionary of named animations
    */
    Animation[string] animations;

    void scanPartsRecurse(ref Node node, bool driversOnly = false) {

        // Don't need to scan null nodes
        if (node is null) return;

        // Collect Drivers
        if (Driver part = cast(Driver)node) {
            drivers ~= part;
            foreach(Parameter param; part.getAffectedParameters())
                drivenParameters[param] = part;
        } else if (!driversOnly) {
            // Collect drawable nodes only if we aren't inside a Composite node

            if (Composite composite = cast(Composite)node) {
                // Composite nodes handle and keep their own root node list, as such we should just draw them directly
                composite.scanParts();
                rootParts ~= composite;

                // For this subtree, only look for Drivers
                driversOnly = true;
            } else if (Part part = cast(Part)node) {
                // Collect Part nodes
                rootParts ~= part;
            }
            // Non-part nodes just need to be recursed through,
            // they don't draw anything.
        }

        // Recurse through children nodes
        foreach(child; node.children) {
            scanPartsRecurse(child, driversOnly);
        }
    }

    final void scanParts(bool reparent = false)(ref Node node) {

        // We want rootParts to be cleared so that we
        // don't draw the same part multiple times
        // and if the node tree changed we want to reflect those changes
        // not the old node tree.
        rootParts = [];

        // Same for drivers
        drivers = [];
        drivenParameters.clear();

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
            b.zSort) > 0, SwapStrategy.stable)(rootParts);
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

    Node findNode(Node n, uint uid) {

        // Name matches!
        if (n.uid == uid) return n;

        // Recurse through children
        foreach(child; n.children) {
            if (Node c = findNode(child, uid)) return c;
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
        Global physics settings for this puppet
    */
    @Name("physics")
    PuppetPhysics physics;

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
        Parameters
    */
    @Name("automation", "Automation")
    @Optional
    Automation[] automation;

    /**
        INP Texture slots for this puppet

        These texture slots are API specific data
    */
    @Ignore
    RuntimeTexture*[] textureSlots;

    /**
        Extended vendor data
    */
    @Ignore
    ubyte[][string] extData;

    /**
        Whether parameters should be rendered
    */
    @Ignore
    bool renderParameters = true;

    /**
        Whether drivers should run
    */
    @Ignore
    bool enableDrivers = true;

    /**
        Puppet render transform

        This transform does not affect physics
    */
    Transform transform;

    /**
        Creates a new puppet from nothing ()
    */
    this() { 
        this.puppetRootNode = new Node(this); 
        this.meta = new PuppetMeta();
        this.physics = new PuppetPhysics();
        root = new Node(this.puppetRootNode); 
        root.name = "Root";
        transform = Transform(vec3(0, 0, 0));
    }

    /**
        Creates a new puppet from a node tree
    */
    this(Node root) {
        this.meta = new PuppetMeta();
        this.physics = new PuppetPhysics();
        this.root = root;
        this.puppetRootNode = new Node(this);
        this.root.name = "Root";
        this.scanParts!true(this.root);
        transform = Transform(vec3(0, 0, 0));
        this.selfSort();
    }

    /**
        Updates the nodes
    */
    final void update() {
        transform.update();

        // Update Automators
        foreach(auto_; automation) {
            auto_.update();
        }

        root.beginUpdate();

        if (renderParameters) {

            // Update parameters
            foreach(parameter; parameters) {

                if (!enableDrivers || parameter !in drivenParameters)
                    parameter.update();
            }
        }

        // Ensure the transform tree is updated
        root.transformChanged();

        if (renderParameters && enableDrivers) {
            // Update parameter/node driver nodes (e.g. physics)
            foreach(driver; drivers) {
                driver.updateDriver();
            }
        }

        // Update nodes
        root.update();
    }

    /**
        Reset drivers/physics nodes
    */
    final void resetDrivers() {
        foreach(driver; drivers) {
            driver.reset();
        }

        // Update so that the timestep gets reset.
        import inochi2d : inUpdate;
        inUpdate();
    }

    /**
        Returns the index of a parameter by name
    */
    ptrdiff_t findParameterIndex(string name) {
        foreach(i, parameter; parameters) {
            if (parameter.name == name) {
                return i;
            }
        }
        return -1;
    }

    /**
        Returns a parameter by UID
    */
    Parameter findParameter(uint uid) {
        foreach(i, parameter; parameters) {
            if (parameter.uid == uid) {
                return parameter;
            }
        }
        return null;
    }

    /**
        Gets if a node is bound to ANY parameter.
    */
    bool getIsNodeBound(Node n) {
        foreach(i, parameter; parameters) {
            if (parameter.hasAnyBinding(n)) return true;
        }
        return false;
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
        Removes a parameter from this puppet
    */
    void removeParameter(Parameter param) {
        import std.algorithm.searching : countUntil;
        import std.algorithm.mutation : remove;
        ptrdiff_t idx = parameters.countUntil(param);
        if (idx >= 0) {
            parameters = parameters.remove(idx);
        }
    }

    /**
        Rescans the puppet's nodes

        Run this every time you change the layout of the puppet's node tree
    */
    final void rescanNodes() {
        this.scanParts!false(root);
    }

    /**
        Updates the texture state for all texture slots.
    */
    final void updateTextureState() {

        // // Update filtering mode for texture slots
        // foreach(texture; textureSlots) {
        //     texture.setFiltering(meta.preservePixels ? Filtering.Point : Filtering.Linear);
        // }
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
    T find(T = Node)(uint uid) if (is(T : Node)) {
        return cast(T)findNode(root, uid);
    }

    /**
        Returns all the parts in the puppet
    */
    Part[] getAllParts() {
        return findNodesType!Part(root);
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
    final uint addTextureToSlot(RuntimeTexture* texture) {
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
        
        foreach(part; getAllParts) {
            foreach(texture; part.textures) {
                if (texture) this.addTextureToSlot(texture);
            }
        }
    }

    /**
        Finds a texture by its runtime UID
    */
    final RuntimeTexture* findTextureByRuntimeUID(uint uid) {
        foreach(ref slot; textureSlots) {
            if (slot.uid)
                return slot;
        }
        return null;
    }

    /**
        Sets thumbnail of this puppet
    */
    final void setThumbnail(RuntimeTexture* texture) {
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
    final ptrdiff_t getTextureSlotIndexFor(RuntimeTexture* texture) {
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

            string s = "%s[%s] %s <%s>\n".format(n.children.length > 0 ? "╭─" : "", n.typeId, n.name, n.uid);
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


    void serializeSelf(ref InochiSerializer serializer) {
        serializer.putKey("meta");
        serializer.serializeValue(meta);
        serializer.putKey("physics");
        serializer.serializeValue(physics);
        serializer.putKey("nodes");
        serializer.serializeValue(root);
        serializer.putKey("param");
        serializer.serializeValue(parameters);
        serializer.putKey("automation");
        serializer.serializeValue(automation);
        serializer.putKey("animations");
        serializer.serializeValue(animations);
    }

    /**
        Serializes a puppet
    */
    void serialize(ref InochiSerializer serializer) {
        auto state = serializer.objectBegin;
        serializeSelf(serializer);
        serializer.objectEnd(state);
    }

    /**
        Deserializes a puppet
    */
    SerdeException deserializeFromFghj(Fghj data) {
        if (auto exc = data["meta"].deserializeValue(this.meta)) return exc;
        if (!data["physics"].isEmpty)
            if (auto exc = data["physics"].deserializeValue(this.physics)) return exc;
        if (auto exc = data["nodes"].deserializeValue(this.root)) return exc;

        // Allow parameter loading to be overridden (for Inochi Creator)
        foreach(key; data["param"].byElement) {
            this.parameters ~= inParameterCreate(key);
        }

        // Deserialize automation
        foreach(key; data["automation"].byElement) {
            string type;
            if (auto exc = key["type"].deserializeValue(type)) return exc;

            if (inHasAutomationType(type)) {
                auto auto_ = inInstantiateAutomation(type, this);
                auto_.deserializeFromFghj(key);
                this.automation ~= auto_;
            }
        }
        if (!data["animations"].isEmpty) data["animations"].deserializeValue(animations);
        this.finalizeDeserialization(data);

        return null;
    }


    void reconstruct() {
        this.root.reconstruct();
        foreach(parameter; parameters.dup) {
            parameter.reconstruct(this);
        }
        foreach(automation_; automation.dup) {
            automation_.reconstruct(this);
        }
        foreach(ref animation; animations.dup) {
            animation.reconstruct(this);
        }
    }

    void finalize() {
        this.root.setPuppet(this);
        this.root.name = "Root";
        this.puppetRootNode = new Node(this);

        // Finally update link etc.
        this.root.finalize();
        foreach(parameter; parameters) {
            parameter.finalize(this);
        }
        foreach(automation_; automation) {
            automation_.finalize(this);
        }
        foreach(ref animation; animations) {
            animation.finalize(this);
        }
        this.scanParts!true(this.root);
        this.selfSort();
    }
    /**
        Finalizer
    */
    void finalizeDeserialization(Fghj data) {
        // reconstruct object path so that object is located at final position
        reconstruct();
        finalize();
    }

    /**
        Gets the internal root parts array 

        Do note that some root parts may be Composites instead.
    */
    final 
    ref Node[] getRootParts() {
        return rootParts;
    }

    /**
        Gets a list of drivers
    */
    final
    ref Driver[] getDrivers() {
        return drivers;
    }

   /**
        Gets a mapping from parameters to their drivers
    */
    final
    ref Driver[Parameter] getParameterDrivers() {
        return drivenParameters;
    }

    /**
        Gets the animation dictionary
    */
    final
    ref Animation[string] getAnimations() {
        return animations;
    }

    void applyDeformToChildren() {
        auto nodes = findNodesType!MeshGroup(root);
        foreach (node; nodes) {
            node.applyDeformToChildren(parameters);
        }
    }

    /**
        Gets the combined bounds of the puppet
    */
    vec4 getCombinedBounds(bool reupdate=false)() {
        return root.getCombinedBounds!(reupdate, true);
    }
}