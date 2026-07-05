/**
    Inochi2D C FFI

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.cffi;
import inochi2d.core.guid;
import nulib.string;
import nulib.quark;
import numem;

version (IN_DYNLIB)  : extern (C) export @nogc:

version (WebAssembly) {
} else version = hasFileIO;

//
//      BASE DATA TYPES
//

/**
    2D Vector
*/
struct in_vec2_t {
    float x;
    float y;
}

/**
    Vertex position vector.
*/
struct in_vtx_t {
    float x;
    float y;
    version (IN_VEC3_POSITION) float z;
}

/**
    A single vertex in the renderer.
*/
struct in_vtxdata_t {
    in_vtx_t vtx;
    in_vec2_t uv;
}

/**
    IO sink functions
*/
struct io_sink_t {

    /**
        Error sink to write errors to.
    */
    extern (C) void function(const(char)* msg, const(char)* file, uint line) @nogc nothrow error;

    /**
        Warning sink to write warnings to.
    */
    extern (C) void function(const(char)* msg, const(char)* file, uint line) @nogc nothrow warning;

    /**
        Info sink to write informational messages to.
    */
    extern (C) void function(const(char)* msg, const(char)* file, uint line) @nogc nothrow info;
}

//
//          TYPEDEFS
//

/**
    A quark.
*/
alias quark_t = uint;

/**
    Opaque handle to a puppet.
*/
struct in_puppet_t;

/**
    Opaque handle to a parameter.
*/
struct in_parameter_t;

/**
    Opaque handle for a node.
*/
struct in_node_t;

/**
    Opaque handle for a mesh effect.
*/
struct in_mesh_effect_t;

/**
    A texture cache.
*/
struct in_texture_cache_t;

/**
    A resource that can be transferred between CPU and GPU.
*/
struct in_resource_t;

/**
    A texture.
*/
struct in_texture_t;

/**
    A drawlist instance
*/
struct in_drawlist_t;

//
//          CORE API
//

/**
    Retains a reference to a Inochi2D Object.

    Params:
        obj = The object to retain.
    
    Returns:
        The object.
*/
void* in_retain(void* obj) {
    return cast(void*)(cast(NuRefCounted)obj).retain();
}

/**
    Releases a reference to a Inochi2D Object.

    Params:
        obj = The object to release.
    
    Returns:
        The object.
*/
void* in_release(void* obj) {
    return cast(void*)(cast(NuRefCounted)obj).release();
}

/**
    Gets the quark associated with the given key string.

    Params:
        key = The key to look up.

    Returns:
        The quark for the given key, or 0.
*/
quark_t quarkof(const(char)* key) {
    return nu_quarkof(cast(string)key.fromStringz());
}

//
//              PUPPET
//

/**
    Loads a puppet into memory.

    Params:
        file =  The file to load.
        sink =  Optional IO sink to write messages to.
    
    Returns:
        A new puppet instance, or $(D null) on failure.
    
    See_Also:
        $(D in_get_last_error)
*/
version(hasFileIO)
in_puppet_t* in_puppet_load(const(char)* file, io_sink_t* sink) {
    import nulib.string : fromStringz;

    __in_clear_error();
    return cast(in_puppet_t*)Puppet.fromFile(cast(string)file.fromStringz, sink ? *cast(IOSink*)sink : IOSink.init).getOr(
            null);
}

/**
    Loads a puppet into memory.

    Params:
        data =      The data of the puppet.
        length =    The length of that data in bytes.
        sink =      Optional IO sink to write messages to.
    
    Returns:
        A new puppet instance, or $(D null) on failure.
    
    See_Also:
        $(D in_get_last_error)
*/
in_puppet_t* in_puppet_load_from_memory(const(ubyte)* data, uint length, io_sink_t* sink) {
    import nulib.io.stream : MemoryStream;

    __in_clear_error();
    auto stream = nogc_new!MemoryStream(cast(ubyte[])data[0 .. length]);
    scope (exit) {
        stream.take();
        nogc_delete(stream);
    }

    auto result = Puppet.fromStream(stream, sink ? *cast(IOSink*)sink : IOSink.init);
    if (!result) {
        __in_set_error(result.error);
        return null;
    }
    return cast(in_puppet_t*)result.getOr(null);
}

/**
    Frees a puppet from memory.

    Notes:
        The main Inochi2D type hirearchy hasn't been converted
        to numem types yet, as such this simply unpins it
        from the D GC.

    Params:
        obj = The puppet object.
*/
void in_puppet_free(in_puppet_t* obj) {
    Puppet puppet = cast(Puppet)obj;
    nogc_delete(puppet);
}

/**
    Gets the name of a puppet.

    Params:
        obj = The puppet object.

    Returns:
        The name of the puppet as specified by
        its author.
*/
const(char)* in_puppet_get_name(in_puppet_t* obj) {
    auto props = (cast(Puppet)obj).properties;
    return (props !is null) ? props.name.ptr : null;
}

/**
    Gets the author of a puppet.

    Params:
        obj = The puppet object.

    Returns:
        The author of the puppet.
*/
const(char)* in_puppet_get_author(in_puppet_t* obj) {
    auto props = (cast(Puppet)obj).properties;
    return (props !is null) ? props.author.ptr : null;
}

/**
    Gets whether to calculate physics for the puppet.

    Params:
        obj = The puppet object.

    Returns:
        Whether physics are enabled.
*/
bool in_puppet_get_physics_enabled(in_puppet_t* obj) {
    return (cast(Puppet)obj).enableDrivers;
}

/**
    Sets whether to calculate physics for the puppet.

    Params:
        obj =   The puppet object.
        value = The value to set.
*/
void in_puppet_set_physics_enabled(in_puppet_t* obj, bool value) {
    (cast(Puppet)obj).enableDrivers = value;
}

/**
    Gets the pixel-to-meter unit mapping for the physics system.

    Params:
        obj = The puppet object.

    Returns:
        A value describing how many pixels count as a meter.
*/
float in_puppet_get_pixels_per_meter(in_puppet_t* obj) {
    return (cast(Puppet)obj).properties.physicsPixelsPerMeter;
}

/**
    Sets the pixel-to-meter unit mapping for the physics system.

    Params:
        obj =   The puppet object.
        value = The value to set.
*/
void in_puppet_set_pixels_per_meter(in_puppet_t* obj, float value) {
    (cast(Puppet)obj).properties.physicsPixelsPerMeter = value;
}

/**
    Gets the gravity constant for the puppet.

    Params:
        obj = The puppet object.

    Returns:
        A value describing how many meters a second gravity
        pulls on the puppet. Normally is 9.8.
*/
float in_puppet_get_gravity(in_puppet_t* obj) {
    return (cast(Puppet)obj).properties.physicsGravity;
}

/**
    Sets the gravity constant for the puppet.

    Params:
        obj =   The puppet object.
        value = The value to set.
*/
void in_puppet_set_gravity(in_puppet_t* obj, float value) {
    (cast(Puppet)obj).properties.physicsGravity = value;
}

/**
    Updates a puppet.

    Params:
        obj = The puppet object.
        delta = Time since last frame.
*/
void in_puppet_update(in_puppet_t* obj, float delta) {
    (cast(Puppet)obj).update(delta);
}

/**
    Draws a puppet.

    Params:
        obj = The puppet object.
        delta = Time since last frame.
*/
void in_puppet_draw(in_puppet_t* obj, float delta) {
    (cast(Puppet)obj).draw(delta);
}

/**
    Resets the physics state for the puppet.

    Params:
        obj = The puppet object.
*/
void in_puppet_reset_drivers(in_puppet_t* obj) {
    assumeNoThrowNoGC(&(cast(Puppet)obj).resetDrivers);
}

/**
    Gets the texture cache belonging to the puppet.

    Params:
        obj = The puppet object.
    
    Returns:
        The texture cache associated with the puppet.
*/
in_texture_cache_t* in_puppet_get_texture_cache(in_puppet_t* obj) {
    return cast(in_texture_cache_t*)(cast(Puppet)obj).textureCache;
}

/**
    Gets the parameters of the puppet.

    Params:
        obj = The puppet object.
        count = Where to store the parameter element count.
    
    Returns:
        A puppet-owned array of parameters.
*/
in_parameter_t** in_puppet_get_parameters(in_puppet_t* obj, ref uint count) {
    count = cast(uint)(cast(Puppet)obj).parameters.length;
    return cast(in_parameter_t**)(cast(Puppet)obj).parameters.ptr;
}

/**
    Gets the puppet's draw list.

    Params:
        obj = The puppet object.
    
    Returns:
        The drawlist used by the puppet.
*/
in_drawlist_t* in_puppet_get_drawlist(in_puppet_t* obj) {
    return cast(in_drawlist_t*)(cast(Puppet)obj).drawList;
}

/**
    Gets the root node of the puppet.

    Params:
        self = The puppet object.

    Returns:
        The root node of the puppet, or $(D null) on failure.
*/
in_node_t* in_puppet_get_root_node(in_puppet_t* self) {
    if (Puppet n_self = cast(Puppet)self)
        return cast(in_node_t*)n_self.root;

    return null;
}

//
//              PARAMETERS
//

/**
    Gets the name of the parameter.
    
    Params:
        obj = The parameter object.
    
    Returns:
        The name of the parameter.
*/
const(char)* in_parameter_get_name(in_parameter_t* obj) {
    return (cast(Parameter)obj).name.ptr;
}

/**
    Gets whether the parameter is active.
    
    Params:
        obj = The parameter object.
    
    Returns:
        $(D true) if the parameter is active,
        $(D false) otherwise.
*/
bool in_parameter_get_active(in_parameter_t* obj) {
    return (cast(Parameter)obj).active;
}

/**
    Gets how many dimensions the parameter has.
    
    Params:
        obj = The parameter object.
    
    Returns:
        A number which indicates how many dimensions
        the parameter has.
*/
uint in_parameter_get_dimensions(in_parameter_t* obj) {
    return (cast(Parameter)obj).dimensions;
}

/**
    Gets the parameter's lower bounds.
    
    Params:
        obj = The parameter object.
    
    Returns:
        Pointer to a series of parameter-owned floats,
        use $(D in_parameter_get_dimensions) to get the dimensionality.
*/
const(float)* in_parameter_get_lower_bounds(in_parameter_t* obj) {
    return (cast(Parameter)obj).lowerBound.ptr;
}

/**
    Gets the parameter's upper bounds.
    
    Params:
        obj = The parameter object.
    
    Returns:
        Pointer to a series of parameter-owned floats,
        use $(D in_parameter_get_dimensions) to get the dimensionality.
*/
const(float)* in_parameter_get_upper_bounds(in_parameter_t* obj) {
    return (cast(Parameter)obj).upperBound.ptr;
}

/**
    Gets the parameter's current value.
    
    Params:
        obj = The parameter object.
    
    Returns:
        Pointer to a series of parameter-owned floats,
        use $(D in_parameter_get_dimensions) to get the dimensionality.
*/
float* in_parameter_get_value(in_parameter_t* obj) {
    return (cast(Parameter)obj).currentValue.ptr;
}

/**
    Sets the parameter's current value.
    
    Params:
        obj =       The parameter object.
        values =    The values to set for the parameter.
*/
void in_parameter_set_value(in_parameter_t* obj, float* values) {
    size_t dims = (cast(Parameter)obj).dimensions;
    (cast(Parameter)obj).currentValue[0 .. dims] = values[0 .. dims];
}

//
//              TEXTURE CACHE
//

/**
    Gets the size (amount of textures) of the texture cache.

    Params:
        obj = The texture cache object.

    Returns:
        The amount of textures within the cache.
*/
uint in_texture_cache_get_size(in_texture_cache_t* obj) {
    return cast(uint)(cast(TextureCache)obj).size;
}

/**
    Gets a texture from the cache.

    Params:
        obj = The texture cache object.
        slot = The slot to get the texture from.

    Returns:
        The requested texture if found,
        otherwise $(D null).
*/
in_texture_t* in_texture_cache_get_texture(in_texture_cache_t* obj, uint slot) {
    return cast(in_texture_t*)(cast(TextureCache)obj).get(slot);
}

/**
    Gets a texture from the cache.

    Params:
        obj = The texture cache object.
        count = Where to store the texture count.

    Returns:
        A puppet-owned array of textures.
*/
in_texture_t** in_texture_cache_get_textures(in_texture_cache_t* obj, ref uint count) {
    count = cast(uint)(cast(TextureCache)obj).size;
    return cast(in_texture_t**)(cast(TextureCache)obj).cache.ptr;
}

/**
    Prunes the texture cache of unreferenced textures.

    Params:
        obj = The texture cache object.
*/
void in_texture_cache_prune(in_texture_cache_t* obj) {
    (cast(TextureCache)obj).prune();
}

//
//              NODE
//

/**
    Creates a new basic node, optionally parented to the given node.

    Params:
        parent = The parent of the newly created node, or null.
    
    Returns:
        The newly allocated node.
*/
in_node_t* in_node_new(in_node_t* parent) {
    return cast(in_node_t*)nogc_new!Node(cast(Node)parent);
}

/**
    Gets the puppet that the node belongs to.

    Params:
        self = The node to operate on.
    
    Returns:
        The parent puppet or $(D null) if puppet is unrooted.
*/
in_puppet_t* in_node_get_puppet(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return cast(in_puppet_t*)n_self.puppet;
    return null;
}

/**
    Gets the parent node of the given node.

    Params:
        self = The node to operate on.
    
    Returns:
        Pointer to the parent node, or $(D null)
        if the node is the root of its tree.
*/
in_node_t* in_node_get_parent(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return cast(in_node_t*)n_self.parent;
    return null;
}

/**
    Sets the parent of the given node.

    Params:
        self =      The node to operate on.
        parent =    The parent to set, or $(D null).
*/
void in_node_set_parent(in_node_t* self, in_node_t* parent) {
    if (Node n_self = cast(Node)self)
        n_self.parent = cast(Node)parent;
}

/**
    Gets the child nodes of the given node.

    Params:
        self =  The node to operate on.
        count = Where to store the node count.

    Returns:
        A node-owned array of nodes.
*/
in_node_t** in_node_get_children(in_node_t* self, uint* count) {
    if (Node n_self = cast(Node)self) {
        *count = cast(uint)n_self.children.length;
        return cast(in_node_t**)n_self.children.ptr;
    }

    return null;
}

/**
    Gets the name of the node.

    Params:
        self = The node to operate on.

    Returns:
        The name of the node.
*/
const(char)* in_node_get_name(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return n_self.name.ptr;

    return null;
}

/**
    Gets the type of the node.

    Params:
        self = The node to operate on.

    Returns:
        The type id of the node.
*/
const(char)* in_node_get_type(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return n_self.typeId.sid.ptr;

    return null;
}

/**
    Gets whether the node is enabled.

    Params:
        self = The node to operate on.

    Returns:
        $(D true) if the node is enabled,
        $(D false) otherwise.
*/
bool in_node_get_enabled(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return n_self.enabled;

    return false;
}

/**
    Sets whether the node is enabled.

    Params:
        self =  The node to operate on.
        value = The value to set.
*/
void in_node_set_enabled(in_node_t* self, bool value) {
    if (Node n_self = cast(Node)self)
        n_self.enabled = value;
}

/**
    Gets whether the node's transform is locked to the root
    node.

    Params:
        self = The node to operate on.

    Returns:
        $(D true) if the transformation of the node is locked
        to the root node, $(D false) otherwise.
*/
bool in_node_get_lock_to_root(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return n_self.lockToRoot;

    return false;
}

/**
    Sets whether the node's transform is locked to the root
    node.

    Params:
        self =  The node to operate on.
        value = The value to set.
*/
void in_node_set_lock_to_root(in_node_t* self, bool value) {
    if (Node n_self = cast(Node)self)
        n_self.lockToRoot = value;
}

/**
    Gets the depth of the node in the node tree.

    Params:
        self =  The node to operate on.
    
    Returns:
        The depth of the node in the tree.
*/
uint in_node_get_tree_depth(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return n_self.depth;

    return 0;
}

/**
    Gets whether the node has the given property.

    Params:
        self =  The node to operate on.
        key =   Name of the property to query.
    
    Returns:
        $(D true) if the node has the given property,
        $(D false) otherwise.
*/
bool in_node_has_property(in_node_t* self, quark_t key) {
    if (key) {
        if (Node n_self = cast(Node)self)
            return n_self.hasProperty(key);
    }
    return false;
}

/**
    Gets the value of the given property.

    Params:
        self =  The node to operate on.
        key =   Name of the property to query.
    
    Returns:
        The value of the property.
*/
float in_node_get_property(in_node_t* self, quark_t key) {
    if (key) {
        if (Node n_self = cast(Node)self)
            return n_self.getProperty(key);
    }
    return 0;
}

/**
    Gets the default value of the given property.

    Params:
        self =  The node to operate on.
        key =   Name of the property to query.
    
    Returns:
        The default value of the property.
*/
float in_node_get_property_default(in_node_t* self, quark_t key) {
    if (key) {
        if (Node n_self = cast(Node)self)
            return n_self.getPropertyDefault(key);
    }
    return 0;
}

/**
    Sets the value of the given property.

    Params:
        self =  The node to operate on.
        key =   Name of the property to query.
        value = Value to assign the property to.
    
    Returns:
        The default value of the property.
*/
void in_node_set_property(in_node_t* self, quark_t key, float value) {
    if (key) {
        if (Node n_self = cast(Node)self)
            return n_self.setProperty(key, value);
    }
}

//
//              PART & MESH EFFECT
//

/**
    Gets the mesh effects attached to a node.

    Params:
        self =  The node to operate on.
        count = Variablt to store the effect count in.
    
    Returns:
        A Part-owned array of mesh effects.
*/
in_mesh_effect_t** in_node_part_get_mesh_effects(in_node_t* self, uint* count) {
    if (Node n_node = cast(Node)self) {
        if (Part n_self = cast(Part)n_node) {
            *count = cast(uint)n_self.effects.length;
            return cast(in_mesh_effect_t**)n_self.effects.ptr;
        }
    }
    return null;
}

/**
    Gets the length of the resource in bytes.

    Params:
        obj = The resource object.
    
    Returns:
        The length of the resource's GPU memory allocation
        in bytes.
*/
uint in_resource_get_length(in_resource_t* obj) {
    return (cast(Resource)obj).length;
}

/**
    Gets the renderer ID of the resource.

    Params:
        obj = The resource object.
    
    Returns:
        The renderer ID of the resource.
*/
void* in_resource_get_id(in_resource_t* obj) {
    return cast(void*)(cast(Resource)obj).id;
}

/**
    Sets the renderer ID of the resource.

    Params:
        obj = The resource object.
        value = The value to set.
*/
void in_resource_set_id(in_resource_t* obj, void* value) {
    (cast(Resource)obj).id = value;
}

//
//              TEXTURES
//

/**
    Creates a texture from a resource.

    Params:
        obj = The resource object.
    
    Returns:
        The texture object that is represented by the
        resource, or $(D null) if the resource is not
        a texture.
*/
in_texture_t* in_texture_from_resource(in_resource_t* obj) {
    return cast(in_texture_t*)(cast(Texture)(cast(Resource)obj));
}

/**
    Gets the width of the texture in pixels.

    Params:
        obj = The texture object.

    Returns:
        The width of the texture in pixels.
*/
uint in_texture_get_width(in_texture_t* obj) {
    return (cast(Texture)obj).width;
}

/**
    Gets the height of the texture in pixels.

    Params:
        obj = The texture object.

    Returns:
        The height of the texture in pixels.
*/
uint in_texture_get_height(in_texture_t* obj) {
    return (cast(Texture)obj).height;
}

/**
    Gets the channels of the texture.

    Params:
        obj = The texture object.

    Returns:
        The channel count of the texture.
*/
uint in_texture_get_channels(in_texture_t* obj) {
    return (cast(Texture)obj).channels;
}

/**
    Flips the texture's data vertically.
    Some engines read in a different direction from Inochi2D.

    Params:
        obj = The texture object.
*/
void in_texture_flip_vertically(in_texture_t* obj) {
    (cast(Texture)obj).data.vflip();
}

/**
    Premultiplies the alpha channel of the texture.

    Params:
        obj = The texture object.
*/
void in_texture_premultiply(in_texture_t* obj) {
    (cast(Texture)obj).data.premultiply();
}

/**
    Un-premultiplies the alpha channel of the texture.

    Params:
        obj = The texture object.
*/
void in_texture_unpremultiply(in_texture_t* obj) {
    (cast(Texture)obj).data.unpremultiply();
}

/**
    Pads the texture with a border.

    Params:
        obj =       The texture object.
        thickness = Thickness of the border in pixels.
*/
void in_texture_pad(in_texture_t* obj, uint thickness) {
    (cast(Texture)obj).data.pad(thickness);
}

/**
    Gets the pixels of the texture.

    Params:
        obj = The texture object.

    Returns:
        The pixels of the texture.
*/
void* in_texture_get_pixels(in_texture_t* obj) {
    return (cast(Texture)obj).pixels.ptr;
}

//
//              DRAWLIST
//

/**
    DrawState flags
*/
alias in_drawstate_t = uint;
enum in_drawstate_t IN_DRAW_STATE_NORMAL = 0,
    IN_DRAW_STATE_DEFINE_MASK = 1,
    IN_DRAW_STATE_MASKED_DRAW = 2,
    IN_DRAW_STATE_COMPOSITE_BEGIN = 3,
    IN_DRAW_STATE_COMPOSITE_END = 4,
    IN_DRAW_STATE_COMPOSITE_BLIT = 5;

/**
    Masking modes
*/
alias in_mask_mode_t = uint;
enum in_mask_mode_t IN_MASK_MODE_MASK = 0,
    IN_MASK_MODE_DODGE = 1;

/**
    Blending modes
*/
alias in_blend_mode_t = uint;
enum in_blend_mode_t IN_BLEND_MODE_NORMAL = 0x00,
    IN_BLEND_MODE_MULTIPLY = 0x01,
    IN_BLEND_MODE_SCREEN = 0x02,
    IN_BLEND_MODE_OVERLAY = 0x03,
    IN_BLEND_MODE_DARKEN = 0x04,
    IN_BLEND_MODE_LIGHTEN = 0x05,
    IN_BLEND_MODE_COLOR_DODGE = 0x06,
    IN_BLEND_MODE_LINEAR_DODGE = 0x07,
    IN_BLEND_MODE_ADD_GLOW = 0x08,
    IN_BLEND_MODE_COLOR_BURN = 0x09,
    IN_BLEND_MODE_HARD_LIGHT = 0x0A,
    IN_BLEND_MODE_SOFT_LIGHT = 0x0B,
    IN_BLEND_MODE_DIFFERENCE = 0x0C,
    IN_BLEND_MODE_EXCLUSION = 0x0D,
    IN_BLEND_MODE_SUBTRACT = 0x0E,
    IN_BLEND_MODE_INVERSE = 0x0F,
    IN_BLEND_MODE_DESTINATION_IN = 0x10,
    IN_BLEND_MODE_SOURCE_IN = 0x11,
    IN_BLEND_MODE_SOURCE_OUT = 0x12;

/**
    A drawing command from the Inochi2D draw list
*/
struct in_drawcmd_t {
    in_texture_t*[IN_MAX_ATTACHMENTS] sources;
    in_drawstate_t state;
    in_blend_mode_t blendMode;
    in_mask_mode_t maskMode;
    uint allocId;
    uint vtxOffset;
    uint idxOffset;
    uint elemCount;
    uint type;
    void[64] vars;
}

/**
    A drawlist mesh allocation
*/
struct in_drawalloc_t {
    uint vtxOffset;
    uint idxOffset;
    uint idxCount;
    uint vtxCount;
    uint allocId;
}

/**
    Gets whether the draw list uses base vertex offsets.

    Params:
        obj = The drawlist
    
    Returns:
        $(D true) if base vertex offsets are being generated,
        $(D false) otherwise.
*/
bool in_drawlist_get_use_base_vertex(in_drawlist_t* obj) {
    return (cast(DrawList)obj).useBaseVertex;
}

/**
    Sets whether the draw list uses base vertex offsets.

    Params:
        obj =   The drawlist
        value = The value to set.
*/
void in_drawlist_set_use_base_vertex(in_drawlist_t* obj, bool value) {
    (cast(DrawList)obj).useBaseVertex = value;
}

/**
    Gets all of the commands stored in the draw list for iteration.
    
    This memory is owned by the draw list and should not be freed
    by you.

    Params:
        obj =   The drawlist
        count = Where to store the command count
    
    Returns:
        A pointer to an array of draw commands
*/
in_drawcmd_t* in_drawlist_get_commands(in_drawlist_t* obj, ref uint count) {
    count = cast(uint)(cast(DrawList)obj).commands.length;
    return cast(in_drawcmd_t*)(cast(DrawList)obj).commands.ptr;
}

/**
    Gets all of the vertex data stored in the draw list.
    
    This memory is owned by the draw list and should not be freed
    by you.

    Params:
        obj =   The drawlist
        bytes = Where to store the byte count of the data.
    
    Returns:
        A pointer to the data
*/
in_vtxdata_t* in_drawlist_get_vertex_data(in_drawlist_t* obj, ref uint bytes) {
    bytes = cast(uint)((cast(DrawList)obj).vertices.length * VtxData.sizeof);
    return cast(in_vtxdata_t*)(cast(DrawList)obj).vertices.ptr;
}

/**
    Gets all of the index data stored in the draw list.
    
    This memory is owned by the draw list and should not be freed
    by you.

    Params:
        obj =   The drawlist
        bytes = Where to store the byte count of the data.
    
    Returns:
        A pointer to the data
*/
void* in_drawlist_get_index_data(in_drawlist_t* obj, ref uint bytes) {
    bytes = cast(uint)((cast(DrawList)obj).indices.length * uint.sizeof);
    return cast(void*)(cast(DrawList)obj).indices.ptr;
}

/**
    Gets all of the allocated meshes of the drawlist.
    
    This memory is owned by the draw list and should not be freed
    by you.

    Params:
        obj =   The drawlist
        count = Where to store the element count
    
    Returns:
        A pointer to the data
*/
in_drawalloc_t* in_drawlist_get_allocations(in_drawlist_t* obj, ref uint count) {
    count = cast(uint)((cast(DrawList)obj).allocations.length);
    return cast(in_drawalloc_t*)(cast(DrawList)obj).allocations.ptr;
}
