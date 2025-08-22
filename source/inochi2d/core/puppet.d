module inochi2d.core.puppet;
import inochi2d.fmt.serde;
import inochi2d.core;
import inochi2d.core.math;
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
    PuppetAllowedUsers allowedUsers = PuppetAllowedUsers.OnlyAuthor;

    /**
        Whether violence content is allowed
    */
    bool allowViolence = false;

    /**
        Whether sexual content is allowed
    */
    bool allowSexual = false;

    /**
        Whether commerical use is allowed
    */
    bool allowCommercial = false;

    /**
        Whether a model may be redistributed
    */
    PuppetAllowedRedistribution allowRedistribution = PuppetAllowedRedistribution.Prohibited;

    /**
        Whether a model may be modified
    */
    PuppetAllowedModification allowModification = PuppetAllowedModification.Prohibited;

    /**
        Whether the author(s) must be attributed for use.
    */
    bool requireAttribution = false;
    
    /**
        Serializes the type.
    */
    void onSerialize(ref JSONValue object) {
        object["allowedUsers"] = this.allowedUsers;
        object["allowViolence"] = this.allowViolence;
        object["allowSexual"] = this.allowSexual;
        object["allowCommercial"] = this.allowCommercial;
        object["allowRedistribution"] = this.allowRedistribution;
        object["allowModification"] = this.allowModification;
        object["requireAttribution"] = this.requireAttribution;
    }
    
    /**
        Deserializes the type.
    */
    void onDeserialize(ref JSONValue object) {
        object.tryGetRef(allowedUsers, "allowedUsers");
        object.tryGetRef(allowViolence, "allowViolence");
        object.tryGetRef(allowSexual, "allowSexual");
        object.tryGetRef(allowCommercial, "allowCommercial");
        object.tryGetRef(allowRedistribution, "allowRedistribution");
        object.tryGetRef(allowModification, "allowModification");
        object.tryGetRef(requireAttribution, "requireAttribution");
    }
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
    string version_ = "0.8.x";

    /**
        Rigger(s) of the puppet
    */
    string rigger;

    /**
        Artist(s) of the puppet
    */
    string artist;

    /**
        Usage Rights of the puppet
    */
    PuppetUsageRights rights;

    /**
        Copyright string
    */
    string copyright;

    /**
        URL of license
    */
    string licenseURL;

    /**
        Contact information of the first author
    */
    string contact;

    /**
        Link to the origin of this puppet
    */
    string reference;

    /**
        Texture ID of this puppet's thumbnail
    */
    uint thumbnailId = NO_THUMBNAIL;

    /**
        Whether the puppet should preserve pixel borders.
        This feature is mainly useful for puppets which use pixel art.
    */
    bool preservePixels = false;
    
    /**
        Serializes the type.
    */
    void onSerialize(ref JSONValue object) {
        object["name"] = this.name;
        object["version"] = this.version_;
        object["rigger"] = this.rigger;
        object["artist"] = this.artist;
        object["rights"] = this.rights.serialize();
        object["copyright"] = this.copyright;
        object["licenseURL"] = this.licenseURL;
        object["contact"] = this.contact;
        object["reference"] = this.reference;
        object["thumbnailId"] = this.thumbnailId;
        object["preservePixels"] = this.preservePixels;
    }
    
    /**
        Deserializes the type.
    */
    void onDeserialize(ref JSONValue object) {
        object.tryGetRef(name, "name");
        object.tryGetRef(version_, "version");
        object.tryGetRef(rigger, "rigger");
        object.tryGetRef(artist, "artist");
        object.tryGetRef(rights, "rights");
        object.tryGetRef(copyright, "copyright");
        object.tryGetRef(licenseURL, "licenseURL");
        object.tryGetRef(contact, "contact");
        object.tryGetRef(reference, "reference");
        object.tryGetRef(thumbnailId, "thumbnailId");
        object.tryGetRef(preservePixels, "preservePixels");
    }
}

/**
    Puppet physics settings
*/
class PuppetPhysics : ISerializable, IDeserializable {
    
    /**
        Pixels-per-meter for the physics system
    */
    float pixelsPerMeter = 1000;
    
    /**
        Gravity for the physics system
    */
    float gravity = 9.8;
    
    /**
        Serializes the type.
    */
    void onSerialize(ref JSONValue object) {
        object["pixelsPerMeter"] = pixelsPerMeter;
        object["gravity"] = gravity;
    }
    
    /**
        Deserializes the type.
    */
    void onDeserialize(ref JSONValue object) {
        object.tryGetRef(pixelsPerMeter, "pixelsPerMeter");
        object.tryGetRef(gravity, "gravity");
    }
}

/**
    A puppet
*/
class Puppet : ISerializable, IDeserializable {
private:
    /**
        An internal puppet root node
    */
    Node puppetRootNode;

    /**
        A list of parts that are not masked by other parts

        for Z sorting
    */
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
    PuppetMeta meta;

    /**
        Global physics settings for this puppet
    */
    PuppetPhysics physics;

    /**
        The root node of the puppet
    */
    Node root;

    /**
        Parameters
    */
    Parameter[] parameters;

    /**
        Parameters
    */
    Automation[] automation;

    /**
        INP Texture slots for this puppet
    */
    Texture[] textureSlots;

    /**
        Extended vendor data
    */
    ubyte[][string] extData;

    /**
        Whether parameters should be rendered
    */
    bool renderParameters = true;

    /**
        Whether drivers should run
    */
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
        Returns a parameter by UUID
    */
    Parameter findParameter(uint uuid) {
        foreach(i, parameter; parameters) {
            if (parameter.uuid == uuid) {
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

        // Update filtering mode for texture slots
        foreach(texutre; textureSlots) {
            texutre.setFiltering(meta.preservePixels ? Filtering.Point : Filtering.Linear);
        }
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
        
        foreach(part; getAllParts) {
            foreach(texture; part.textures) {
                if (texture) this.addTextureToSlot(texture);
            }
        }
    }

    /**
        Finds a texture by its runtime UUID
    */
    final Texture findTextureByRuntimeUUID(uint uuid) {
        foreach(ref slot; textureSlots) {
            if (slot.getRuntimeUUID())
                return slot;
        }
        return null;
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
        Serializes a puppet.
    */
    JSONValue serialize() {
        JSONValue object = JSONValue.emptyObject;
        this.onSerialize(object);
        return object;
    }

    /**
        Serializes a puppet into an existing object.
    */
    void onSerialize(ref JSONValue object) {

        // Meta Info
        object["meta"] = JSONValue.emptyObject;
        object["meta"]["name"] = meta.name;
        object["meta"]["version"] = meta.version_;
        object["meta"]["rigger"] = meta.rigger;
        object["meta"]["artist"] = meta.artist;
        object["meta"]["copyright"] = meta.copyright;
        object["meta"]["licenseURL"] = meta.licenseURL;
        object["meta"]["contact"] = meta.contact;
        object["meta"]["reference"] = meta.reference;
        object["meta"]["thumbnailId"] = meta.thumbnailId;
        object["meta"]["preservePixels"] = meta.preservePixels;
        
        // Meta Rights Info
        if (meta.rights) {
            object["meta"]["rights"] = JSONValue.emptyObject;
            object["meta"]["rights"]["allowedUsers"] = meta.rights.allowedUsers;
            object["meta"]["rights"]["allowViolence"] = meta.rights.allowViolence;
            object["meta"]["rights"]["allowSexual"] = meta.rights.allowSexual;
            object["meta"]["rights"]["allowCommercial"] = meta.rights.allowCommercial;
            object["meta"]["rights"]["allowRedistribution"] = meta.rights.allowRedistribution;
            object["meta"]["rights"]["allowModification"] = meta.rights.allowModification;
            object["meta"]["rights"]["requireAttribution"] = meta.rights.requireAttribution;
        }

        // Physics Info
        object["physics"] = JSONValue.emptyObject;
        object["physics"]["pixelsPerMeter"] = physics.pixelsPerMeter;
        object["physics"]["gravity"] = physics.gravity;

        // Create objects for nodes, params, automation and animation.
        object["nodes"] = root.serialize();
        object["param"] = parameters.serialize();
        object["automation"] = automation.serialize();
        object["animations"] = animations.serialize();
    }

    /**
        Deserializes a puppet
    */
    static Puppet deserialize(ref JSONValue object) {
        Puppet p = new Puppet();
        p.onDeserialize(object);
        return p;
    }

    /**
        Deserializes a puppet
    */
    void onDeserialize(ref JSONValue object) {
        
        // Invalid type.
        if (!object.isJsonObject)
            return;

        object.tryGetRef(meta, "meta");
        object.tryGetRef(physics, "physics");
        object.tryGetRef(root, "nodes");
        object.tryGetRef(parameters, "param");
        object.tryGetRef(animations, "animations");

        // Deserialize automation
        if (object.isJsonArray("automation")) {
            foreach(element; object["automation"].array) {
                if (string type = element.tryGet!string("type", null)) {
                    if (inHasAutomationType(type)) {
                        auto auto_ = inInstantiateAutomation(type, this);
                        element.deserialize(auto_);
                        this.automation ~= auto_;
                    }
                }
            }
        }

        this.finalizeDeserialization(object);
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
    void finalizeDeserialization(JSONValue data) {
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