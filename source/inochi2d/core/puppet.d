module inochi2d.core.puppet;
import inochi2d.core.format;
import inochi2d.core.render;
import inochi2d.core.math;
import inochi2d.core;
import std.algorithm.sorting;
import std.algorithm.mutation : SwapStrategy;
import std.exception;
import std.format;
import std.file;
import std.path : extension;
import std.json;
import nulib;
import numem;

/**
    Magic value meaning that the model has no thumbnail
*/
enum NO_THUMBNAIL = uint.max;

/**
    Puppet properties
*/
class PuppetProperties : ISerializable, IDeserializable {
public:

    /**
        Parent puppet object
    */
    Puppet parent;

    /**
        Name of the puppet
    */
    nstring name;

    /**
        Author of the puppet
    */
    nstring author;

    /**
        Thumbnail of the puppet.
    */
    Texture thumbnail;

    /**
        Pixels-per-meter for the physics system
    */
    float physicsPixelsPerMeter = 1000;
    
    /**
        Gravity for the physics system
    */
    float physicsGravity = 9.8;

    /**
        Whether the puppet should preserve pixel borders.
        This feature is mainly useful for puppets which use pixel art.
    */
    bool graphicsUsePointFiltering = false;

    /**
        Constructs a new properties object.
    */
    this(Puppet puppet) @nogc {
        this.parent = puppet;
    }
    
    /**
        Serializes the type.
    */
    void onSerialize(ref JSONValue object, bool recursive = true) {

        // General Properties.
        object["name"] = name[];
        object["author"] = author[];
        object["thumbnail"] = parent.textureCache.find(thumbnail);


        // Physics properties.
        object["physicsPixelsPerMeter"] = physicsPixelsPerMeter;
        object["physicsGravity"] = physicsGravity;

        // Graphics properties
        object["graphicsUsePointFiltering"] = graphicsUsePointFiltering;
    }
    
    /**
        Deserializes the type.
    */
    void onDeserialize(ref JSONValue object) {
        object.tryGetRef(physicsPixelsPerMeter, "pixelsPerMeter");
        object.tryGetRef(physicsGravity, "gravity");
    }
}

/**
    A puppet
*/
class Puppet : ISerializable, IDeserializable {
private:
    /**
        The drawlist that the puppet passes to its nodes.
    */
    DrawList drawList_;

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
        if (Driver driver = cast(Driver)node) {
            drivers ~= driver;
            foreach(Parameter param; driver.affectedParameters)
                drivenParameters[param] = driver;
            
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

    void scanParts(bool reparent = false)(ref Node node) {

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

    Node findNode(Node n, GUID guid) {

        // Name matches!
        if (n.guid == guid) return n;

        // Recurse through children
        foreach(child; n.children) {
            if (Node c = findNode(child, guid)) return c;
        }

        // Not found
        return null;
    }

protected:


    /**
        Serializes a puppet into an existing object.
    */
    void onSerialize(ref JSONValue object, bool recursive) {
        object["properties"] = properties.serialize();

        // Create objects for nodes, params, automation and animation.
        object["nodes"] = root.serialize();
        object["param"] = parameters.serialize();
        object["animations"] = animations.serialize();
    }

    /**
        Deserializes a puppet
    */
    void onDeserialize(ref JSONValue object) {
        
        // Invalid type.
        if (!object.isJsonObject)
            return;

        object.tryGetRef(properties, "settings");
        object.tryGetRef(root, "nodes");
        object.tryGetRef(parameters, "param");
        object.tryGetRef(animations, "animations");

        // Legacy "meta" key.
        if (object.hasKey("meta")) {
            object["meta"].tryGetRef(properties.graphicsUsePointFiltering, "preservePixels");
        }

        // Legacy "physics" key.
        if (object.hasKey("physics")) {
            object["physics"].tryGetRef(properties.physicsPixelsPerMeter, "pixelsPerMeter");
            object["physics"].tryGetRef(properties.physicsGravity, "gravity");
        }

        this.reconstruct();
        this.finalize();
    }

    void reconstruct() {
        this.root.reconstruct();
        foreach(parameter; parameters.dup) {
            parameter.reconstruct(this);
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
        foreach(ref animation; animations) {
            animation.finalize(this);
        }
        this.scanParts!true(this.root);
        this.selfSort();
    }

public:

    /**
        Properties for the puppet.
    */
    PuppetProperties properties;

    /**
        The root node of the puppet
    */
    Node root;

    /**
        Parameters
    */
    Parameter[] parameters;

    /**
        INP Texture slots for this puppet
    */
    TextureCache textureCache;

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
        The active draw list for the puppet.
    */
    @property DrawList drawList() @nogc => drawList_;

    // Destructor
    ~this() {
        nogc_delete(properties);

        nogc_delete(drawList_);
        nogc_delete(textureCache);
    }

    /**
        Creates a new puppet from nothing ()
    */
    this(TextureCache cache = null) {
        this.properties = nogc_new!PuppetProperties(this);

        this.puppetRootNode = new Node(this); 
        this.root = new Node(this.puppetRootNode); 
        this.root.name = "Root";

        this.textureCache = cache ? cache : nogc_new!TextureCache();
        this.drawList_ = nogc_new!DrawList();
    }

    /**
        Creates a new puppet from a node tree
    */
    this(Node root) {
        this.properties = nogc_new!PuppetProperties(this);
        this.root = root;
        this.puppetRootNode = new Node(this);
        this.root.name = "Root";
        this.scanParts!true(this.root);
        this.selfSort();

        this.drawList_ = nogc_new!DrawList();
        this.textureCache = nogc_new!TextureCache();
    }

    /**
        Updates the nodes
    */
    final void update(float delta) {
        drawList_.clear();
        transform.update();
        root.preUpdate(drawList_);

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
                driver.updateDriver(delta);
            }
        }

        // Update nodes
        root.update(delta, drawList_);
        root.postUpdate(drawList_);
    }

    /**
        Reset drivers/physics nodes
    */
    final void resetDrivers() {
        foreach(driver; drivers) {
            driver.reset();
        }
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
        Returns a parameter by GUID
    */
    Parameter findParameter(GUID guid) {
        foreach(i, parameter; parameters) {
            if (parameter.guid == guid) {
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
    final void draw(float delta) {
        this.selfSort();

        foreach(rootPart; rootParts) {
            if (!rootPart.renderEnabled) 
                continue;
            
            rootPart.draw(delta, drawList_);
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
        Finds Node by its name
    */
    T find(T = Node)(string name) if (is(T : Node)) {
        return cast(T)findNode(root, name);
    }

    /**
        Finds Node by its unique id
    */
    T find(T = Node)(GUID guid) if (is(T : Node)) {
        return cast(T)findNode(root, guid);
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
    T[] findNodesType(T)(Node n) if (is(T : Node)) {
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
        return textureCache.add(texture);
    }

    /**
        Sets thumbnail of this puppet
    */
    final void setThumbnail(Texture texture) {
        textureCache.add(texture);
        this.properties.thumbnail = texture;
    }

    /**
        Gets the texture slot index for a texture

        returns -1 if none was found
    */
    final ptrdiff_t getTextureSlotIndexFor(Texture texture) {
        return textureCache.find(texture);
    }

    /**
        Serializes a puppet.
    */
    JSONValue serialize() {
        JSONValue object = JSONValue.emptyObject;
        this.onSerialize(object, true);
        return object;
    }

    /**
        Deserializes a puppet
    */
    static Puppet deserialize(ref JSONValue object, TextureCache cache) {
        Puppet p = new Puppet(cache);
        p.onDeserialize(object);
        return p;
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

    /**
        Gets the combined bounds of the puppet
    */
    vec4 getCombinedBounds(bool reupdate=false)() {
        return root.getCombinedBounds!(reupdate, true);
    }
}