/**
    Root Puppet Object

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.puppet;
import inochi2d.common;
import inochi2d.nodes;
import inochi2d.param;
import inochi2d.animation;
import inochi2d.core;
import inp.format;
import nulib.io.stream;
import nulib;
import numem;

// NOTE:    Puppet has some legacy functionality, this allows turning that off.
version (IN_NO_LEGACY) {
} else {
    pragma(msg, "WARNING: Legacy features are enabled, these may be removed in future updates.");
    version = IN_LEGACY;
}

/**
    Puppet properties
*/
class PuppetProperties : NuObject, ISerializable, IDeserializable!ModelState {
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
    void onSerialize(ref DataNode object) @nogc {

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
    void onDeserialize(ref DataNode object, ref ModelState state) @nogc {

        // 0.8 backwards compatibility.
        object.tryGetRef(state, author, "rigger", author);
        object.tryGetRef(state, author, "artist", author);

        object.tryGetRef(state, name, "name");
        object.tryGetRef(state, author, "author", author);
        object.tryGetRef(state, physicsPixelsPerMeter, "pixelsPerMeter");
        object.tryGetRef(state, physicsGravity, "gravity");
    }
}

/**
    A puppet
*/
class Puppet : NuRefCounted, ISerializable, IDeserializable!ModelState {
private:
@nogc:

    // The drawlist that the puppet passes to its nodes.
    DrawList drawList_;

    // A list of parts that are not masked by other parts
    weak_vector!Visual visuals_;

    // A list of parameters attached to the puppet.
    vector!Parameter parameters_;

    // A dictionary of named animations
    vector!Animation animations_;

    // Extended Vendor Data
    weak_map!(string, ubyte[]) vendorData_;

    //
    //          LEGACY CONSTRUCTS
    //
    version (IN_LEGACY) {

        // A list of parameters that are driven by drivers
        weak_map!(Parameter, SimplePhysics) driven_;

        // A list of drivers that need to run to update the puppet
        SimplePhysics[] drivers_;
    }

    void scanParts(ref Node node) {
        node.findVisuals(visuals_);

        // Legacy physics system.
        version (IN_LEGACY) {
            node.findNodes!SimplePhysics(drivers_);
            driven_.clear();
            foreach (driver; drivers_) {
                foreach (Parameter param; driver.affectedParameters)
                    driven_[param] = driver;
            }
        }
    }

    Node findNode(Node n, string name) @nogc {

        // Name matches!
        if (n.name == name)
            return n;

        // Recurse through children
        foreach (child; n.children) {
            if (Node c = findNode(child, name))
                return c;
        }

        // Not found
        return null;
    }

    Node findNode(Node n, GUID guid) @nogc {

        // Name matches!
        if (n.guid == guid)
            return n;

        // Recurse through children
        foreach (child; n.children) {
            if (Node c = findNode(child, guid))
                return c;
        }

        // Not found
        return null;
    }

    /// Loads textures from a DataNode into the texture cache.
    void loadTextures(ref DataNode node) {
        assert(textureCache !is null, "Texture cache is invalid!");
        assert(node.isArray, "Not a texture cache array!");

        texLoadLoop: foreach (i, ref DataNode texture; node.array) {
            TextureData textureData;

            // Skip invalid texture indices.
            if (!texture.isObject || "encoding" !in texture || "data" !in texture)
                continue;

            uint encoding = texture["encoding"].tryCoerce!int(-1);
            ubyte[] data = texture["data"].blob;

            // Invalid data?
            if (encoding == -1 || data.length == 0)
                continue;

            // Handle different encodings.
            switch (encoding) {
            case INP_TEX_FMT_PNG:
            case INP_TEX_FMT_TGA:
                textureData = TextureData.load(data);
                break;

            case INP_TEX_FMT_BC7:
                assert(0, "BC7 not implemented yet!");
                continue texLoadLoop;

            default:
                // Unknown format.
                continue texLoadLoop;
            }
            textureCache.insert(Texture.createForData(textureData.move()), i);
        }
    }

protected:

    /**
        Serializes a puppet into an existing object.
    */
    void onSerialize(ref DataNode object) @nogc {
        object["properties"] = properties.serialize();
        object["nodes"] = root.serialize();
        object["param"] = parameters_.serialize();
        object["animations"] = animations_.serialize();
    }

    /**
        Deserializes a puppet
    */
    void onDeserialize(ref DataNode object, ref ModelState state) @nogc {

        // Invalid type.
        if (!object.isObject)
            return;

        // Just set to basic initialized object if none was found.
        object.tryGetRef(state, properties, "properties", properties);

        // Legacy "meta" key.
        if ("meta" in object) {
            object.tryGetRef(state, properties, "meta", properties);
            object["meta"].tryGetRef(state, properties.graphicsUsePointFiltering, "preservePixels");
        }

        // Legacy "physics" key.
        if ("physics" in object) {
            object["physics"].tryGetRef(state, properties.physicsPixelsPerMeter, "pixelsPerMeter");
            object["physics"].tryGetRef(state, properties.physicsGravity, "gravity");
        }

        // Add root node if it was found.
        if ("nodes" in object) {
            object.tryGetRef(state, root, "nodes", root);
        }

        if (auto params = "param" in object) {
            if ((*params).isArray) {
                parameters_.resize((*params).length);
                foreach (i, ref param; (*params).array) {
                    parameters_[i] = param.tryDeserializeParam(state);
                }
            }
        }

        if (auto anim = "animation" in object) {
            (*anim).deserialize(animations_, state);
        }
    }

    void onFinalize(ref ModelState state) @nogc {

        // Finally update link etc.
        this.root.finalize(state);
        this.root.updateTransform();

        foreach (parameter; parameters_) {
            parameter.finalize(this, state);
        }

        foreach (ref animation; animations_) {
            animation.finalize(this);
        }
        this.rescanNodes();
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
    version (IN_LEGACY) bool enableDrivers = true;

    /**
        Puppet render transform

        This transform does not affect physics
    */
    Transform transform;

    /**
        The active draw list for the puppet.
    */
    final @property DrawList drawList() @nogc => drawList_;

    /**
        A read-only slice of the root visuals being rendered.
    */
    final @property Visual[] visuals() => visuals_;

    /**
        A read-only slice of drivers
    */
    version (IN_LEGACY) final @property SimplePhysics[] drivers() => drivers_;

    /**
        A read-only slice of animations attached to this puppet.
    */
    final @property Animation[] animations() => animations_[];

    /**
        A read-only slice of animations attached to this puppet.
    */
    final @property Parameter[] parameters() => parameters_[];

    // Destructor
    ~this() {
        nogc_delete(properties);
        nogc_delete(drawList_);
        nogc_delete(textureCache);
    }

    /**
        Constructs a new, empty puppet.

        Params:
            cache = The texture cache to use during construction.
            root =  The node to put as the root of the puppet.
    */
    this(TextureCache cache = null, Node root = null) {
        this.properties = nogc_new!PuppetProperties(this);
        this.textureCache = cache ? cache : nogc_new!TextureCache();
        this.drawList_ = nogc_new!DrawList();

        // Setup root node
        this.root = root ? root : nogc_new!Node(this);
        this.root.setPuppet(this);
        this.root.name = "Root";
    }

    /**
        Creates a new puppet from a node tree
    */
    this(Node root) {
        this(null, root);
    }

    version (WebAssembly) {
    } else {

        /**
            Loads a $(D Puppet) from a file.

            Params:
                path =  Path to the file to load.
                sink =  A sink to write logs to.
            
            Notes:
                Not available when compiling for WebAssembly.
        */
        static Result!Puppet fromFile(string path, IOSink sink = IOSink.init) @nogc {
            import nulib.io.stream.file : FileStream;

            if (FileStream fstream = nogc_new!FileStream(path, "r+b")) {
                return Puppet.fromStream(fstream, sink);
            }
            return error!Puppet("Could not open file.");
        }
    }

    /**
        Loads a $(D Puppet) from a Stream.

        Params:
            stream =    The readable stream to load the puppet from.
            sink =      A sink to write logs to.
    */
    static Result!Puppet fromStream(Stream stream, IOSink sink = IOSink.init) @nogc {
        assert(stream);
        assert(stream.canRead);

        // Set up model state.
        ModelState state;
        state.io = sink;

        // Identify Inochi2D 0.8 models.
        INPFileFormat fileFormat = stream.detectFormat();
        if (fileFormat == INPFileFormat.inp1) {
            state.doUpgrade08 = true;
            state.version_ = IN_MAKE_VERSION!(0, 8, 6);
            state.warning("Inochi2D 0.8's file format is deprecated, it is recommended that you upgrade to Inochi2D 0.9.");
        }

        auto result = stream.readINP();
        if (!result)
            return error!Puppet(result.error);

        DataNode node = result.get();
        if (INP_TAG_PAYLOAD !in node)
            return error!Puppet("No payload was found in the model!");

        // Create new puppet and deserialize the data.
        Puppet puppet = nogc_new!Puppet(nogc_new!TextureCache());
        puppet.deserialize(node, state);
        return ok(puppet);
    }

    /**
        Loads a $(D Puppet) from a Stream.

        Params:
            stream = The readable stream to load the puppet from.
    */
    final bool toStream(Stream stream) @nogc {
        assert(stream);
        assert(stream.canWrite);

        // Prepare data node.
        DataNode data = DataNode.createObject();
        data[INP_TAG_PAYLOAD] = DataNode.createObject();
        data[INP_TAG_TEXTURES] = DataNode.createArray();

        // Serialize data
        return false;
    }

    /**
        Serializes a puppet.

        Params:
            node =  The payload DataNode to deserialize from.
    */
    final void serialize(ref DataNode node) {
        assert(node.isObject, "Target DataNode was not an Object!");
        node[INP_TAG_PAYLOAD] = DataNode.createObject();
        this.onSerialize(node[INP_TAG_PAYLOAD]);
    }

    /**
        Deserializes a Puppet from a payload $(D DataNode).

        Params:
            node =  The DataNode to deserialize from.
            state = The state of the deserializer.
    */
    final void deserialize(ref DataNode node, ref ModelState state) @nogc {
        assert(INP_TAG_PAYLOAD in node, "No payload was found!");
        assert(node[INP_TAG_PAYLOAD].isObject, "Invalid payload object.");

        // NOTE:    Deserialization happens in multiple steps,
        //          1. Load textures from TEX_SECT, assigning texture IDs.
        //          2. Deserialize payload, (this MUST be present.)
        //          3. Finalize any data.
        if (INP_TAG_TEXTURES in node) {
            this.loadTextures(node[INP_TAG_TEXTURES]);
        }

        this.onDeserialize(node[INP_TAG_PAYLOAD], state);
        this.onFinalize(state);
    }

    /**
        Updates the nodes
    */
    final void update(float delta) {
        drawList_.clear();
        root.preUpdate(drawList_);

        // Update parameters
        if (renderParameters) {
            foreach (parameter; parameters_) {
                parameter.update();
            }
        }

        // Ensure the transform tree is updated
        root.updateTransform();

        version (IN_LEGACY) {
            if (renderParameters && enableDrivers) {
                // Update parameter/node driver nodes (e.g. physics)
                foreach (driver; drivers_) {
                    driver.updateDriver(delta);
                }
            }

            // Update again after drivers.
            root.updateTransform();
        }

        // Update nodes
        root.update(delta, drawList_);
        root.postUpdate(drawList_);
    }

    /**
        Reset drivers/physics nodes
    */
    version (IN_LEGACY) final void resetDrivers() @nogc {
        foreach (driver; drivers_) {
            driver.reset();
        }
    }

    /**
        Returns the index of a parameter by name
    */
    ptrdiff_t findParameterIndex(string name) @nogc {
        foreach (i, parameter; parameters_) {
            if (parameter.name == name) {
                return i;
            }
        }
        return -1;
    }

    /**
        Returns a parameter by GUID
    */
    Parameter findParameter(GUID guid) @nogc {
        foreach (i, parameter; parameters_) {
            if (parameter.guid == guid) {
                return parameter;
            }
        }
        return null;
    }

    /**
        Gets if a node is bound to ANY parameter.
    */
    bool getIsNodeBound(Node node) {
        foreach (i, parameter; parameters_) {
            if (parameter.hasAnyBindingsTo(node))
                return true;
        }
        return false;
    }

    /**
        Draws the puppet
    */
    final void draw(float delta) {
        sortNodes(visuals_);

        foreach (visual; visuals_) {
            if (!visual.enabled)
                continue;

            visual.draw(delta, drawList_);
        }
    }

    /**
        Removes a parameter from this puppet
    */
    void addParameter(Parameter param) {
        parameters_ ~= param;
    }

    /**
        Removes a parameter from this puppet
    */
    void removeParameter(Parameter param) {
        parameters_.remove(param);
    }

    /**
        Rescans the puppet's nodes

        Run this every time you change the layout of the puppet's node tree
    */
    final void rescanNodes() {
        this.scanParts(root);
    }

    /**
        Finds Node by its name
    */
    T find(T = Node)(string name) @nogc
    if (is(T : Node)) {
        return cast(T)findNode(root, name);
    }

    /**
        Finds Node by its unique id
    */
    T find(T = Node)(GUID guid) @nogc
    if (is(T : Node)) {
        return cast(T)findNode(root, guid);
    }

    /**
        Adds a texture to a new slot if it doesn't already exist within this puppet
    */
    final uint addTextureToSlot(Texture texture) @nogc {
        return textureCache.add(texture);
    }

    /**
        Sets thumbnail of this puppet
    */
    final void setThumbnail(Texture texture) @nogc {
        textureCache.add(texture);
        this.properties.thumbnail = texture;
    }

    /**
        Gets the texture slot index for a texture

        returns -1 if none was found
    */
    final ptrdiff_t getTextureSlotIndexFor(Texture texture) @nogc {
        return textureCache.find(texture);
    }

    /**
        Gets the combined bounds of the puppet
    */
    vec4 getCombinedBounds(bool reupdate = false)() {
        return root.getCombinedBounds!(reupdate, true);
    }
}
