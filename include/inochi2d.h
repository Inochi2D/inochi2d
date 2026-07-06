// Inochi2D C FFI
//
// BSD 2-Clause License
//
// Copyright © 2020-2026, Inochi2D Project
// Copyright © 2020-2026, Kitsunebi Games
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
// this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifndef H_INOCHI2D
#define H_INOCHI2D




//
//      PLATFORM MACROS
//

// Figure out if we are compiling for WASM.
#if __EMSCRIPTEN__ || __wasm32__ || __wasm__
#define IN_WASM
#endif

// Handle calling convention on Windows.
// This will ensure MSVC does not try to use stdcall
// when the D library uses cdecl.
#ifdef _WIN32
#ifdef _MSC_VER
#define IN_CALL __cdecl
#else
#define IN_CALL
#endif
#else
#define IN_CALL
#endif

// Handle feature flags.
#if _WIN32
#define IN_HAVE_FILEIO
#elif __linux__
#define IN_HAVE_FILEIO
#elif __APPLE__
#define IN_HAVE_FILEIO
#else
#endif




//
//      CONFIGURATION MACROS
//

// The maximum number of attachments in a draw command.
#ifndef IN_MAX_ATTACHMENTS
#define IN_MAX_ATTACHMENTS 8
#endif

#ifdef __cplusplus
extern "C" {
#endif
//
//          TYPEDEFS
//

/**
    A quark.
*/
typedef uint32_t quark_t;

/**
    Opaque handle to a puppet.
*/
typedef struct in_puppet_t in_puppet_t;

/**
    Opaque handle to a parameter.
*/
typedef struct in_parameter_t in_parameter_t;

/**
    Opaque handle for a node.
*/
typedef struct in_node_t in_node_t;

/**
    Opaque handle for a visual node.
*/
typedef struct in_visual_t in_visual_t;

/**
    Opaque handle for a part node.
*/
typedef struct in_part_t in_part_t;

/**
    Opaque handle for a animated part node.
*/
typedef struct in_animated_part_t in_animated_part_t;

/**
    Opaque handle for a compsite node.
*/
typedef struct in_composite_t in_composite_t;

/**
    Opaque handle for a mask node.
*/
typedef struct in_mask_t in_mask_t;

/**
    Opaque handle for a solo node.
*/
typedef struct in_solo_t in_solo_t;

/**
    Opaque handle for a deformer node.
*/
typedef struct in_deformer_t in_deformer_t;

/**
    Opaque handle for a bone node.
*/
typedef struct in_bone_t in_bone_t;

/**
    Opaque handle for a bone modifier node.
*/
typedef struct in_bone_modifier_t in_bone_modifier_t;

/**
    Opaque handle for a mesh.
*/
typedef struct in_mesh_t in_mesh_t;

/**
    Opaque handle for a mesh effect.
*/
typedef struct in_mesh_effect_t in_mesh_effect_t;

/**
    Opaque handle for a texture cache.
*/
typedef struct in_texture_cache_t in_texture_cache_t;

/**
    Opaque handle for a resource that can be
    transferred between CPU and GPU.
*/
typedef struct in_resource_t in_resource_t;

/**
    Opaque handle for a texture.
*/
typedef struct in_texture_t in_texture_t;

/**
    Opaque handle for a drawlist.
*/
typedef struct in_drawlist_t in_drawlist_t;




//
//      BASE DATA TYPES
//

/**
    2D Vector
*/
typedef struct in_vec2_t {
    float x;
    float y;
} in_vec2_t;

/**
    Vertex position vector.
*/
typedef struct in_vtx_t {
    float x;
    float y;
#ifdef IN_VEC3_POSITION
    float z;
#endif
} in_vtx_t;

/**
    A single vertex in the renderer.
*/
typedef struct in_vtxdata_t {
    in_vtx_t vtx;
    in_vec2_t uv;
} in_vtxdata_t;

/**
    A GUID.
*/
typedef struct in_guid_t {
    uint8_t data[16];
} in_guid_t;

/**
    IO sink functions
*/
typedef struct io_sink_t {

    /**
        Error sink to write errors to.
    */
    void (*error)(const char *msg, const char *file, uint32_t line);

    /**
        Warning sink to write warnings to.
    */
    void (*warning)(const char *msg, const char *file, uint32_t line);

    /**
        Info sink to write informational messages to.
    */
    void (*info)(const char *msg, const char *file, uint32_t line);

} io_sink_t;

/**
    DrawState flags
*/
typedef enum {
    IN_DRAW_STATE_NORMAL = 0,
    IN_DRAW_STATE_DEFINE_MASK = 1,
    IN_DRAW_STATE_PUSH_MASK = 2,
    IN_DRAW_STATE_POP_MASK = 3,
    IN_DRAW_STATE_COMPOSITE_BEGIN = 4,
    IN_DRAW_STATE_COMPOSITE_END = 5,
    IN_DRAW_STATE_COMPOSITE_BLIT = 6,
    IN_DRAW_STATE_MAX = 0xFFFFFFFFU
} in_drawstate_t;

/**
    Masking modes
*/
typedef enum { 
    IN_MASK_MODE_MASK = 0, 
    IN_MASK_MODE_DODGE = 1, 
    IN_MASK_MODE_MAX = 0xFFFFFFFFU
} in_mask_mode_t;

/**
    Blending modes
*/
typedef enum {
    IN_BLEND_MODE_NORMAL = 0x00,
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
    IN_BLEND_MODE_SOURCE_OUT = 0x12,
    IN_BLEND_MODE_MAX = 0xFFFFFFFFU
} in_blend_mode_t;

/**
    A drawing command from the Inochi2D draw list
*/
typedef struct in_drawcmd_t {
    in_texture_t *sources[IN_MAX_ATTACHMENTS];
    in_drawstate_t state;
    in_blend_mode_t blendMode;
    in_mask_mode_t maskMode;
    uint32_t allocId;
    uint32_t vtxOffset;
    uint32_t idxOffset;
    uint32_t elemCount;
    uint32_t type;
    unsigned char vars[64];
} in_drawcmd_t;

/**
    A drawlist mesh allocation
*/
typedef struct in_drawalloc_t {
    uint32_t vtxOffset;
    uint32_t idxOffset;
    uint32_t idxCount;
    uint32_t vtxCount;
    uint32_t allocId;
} in_drawalloc_t;




//
//          STATIC DEFINITIONS
//

/**
    A nil GUID.
*/
#define IN_GUID_NIL in_guid_t({0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0})




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
void *IN_CALL in_retain(void *obj);

/**
    Releases a reference to a Inochi2D Object.

    Params:
        obj = The object to release.

    Returns:
        The object.
*/
void *IN_CALL in_release(void *obj);

/**
    Gets a quark for a key string.

    Params:
        key = The key to get the quark of.

    Returns:
        The quark for the given key if found,
        0 otherwise.
*/
quark_t IN_CALL quarkof(const char *key);




//
//              PUPPET
//

#ifdef IN_HAVE_FILEIO
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
in_puppet_t *IN_CALL in_puppet_load(const char *file, io_sink_t *sink);
#endif

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
in_puppet_t *IN_CALL in_puppet_load_from_memory(const uint8_t *data, uint32_t length, io_sink_t *sink);

/**
    Frees a puppet from memory.

    Notes:
        The main Inochi2D type hirearchy hasn't been converted
        to numem types yet, as such this simply unpins it
        from the D GC.

    Params:
        obj = The puppet object.
*/
void IN_CALL in_puppet_free(in_puppet_t *obj);

/**
    Gets the name of a puppet.

    Params:
        obj = The puppet object.

    Returns:
        The name of the puppet as specified by
        its author.
*/
const char *IN_CALL in_puppet_get_name(in_puppet_t *obj);

/**
    Gets the author of a puppet.

    Params:
        obj = The puppet object.

    Returns:
        The author of the puppet.
*/
const char *IN_CALL in_puppet_get_author(in_puppet_t *obj);

/**
    Gets whether to calculate physics for the puppet.

    Params:
        obj = The puppet object.

    Returns:
        Whether physics are enabled.
*/
bool IN_CALL in_puppet_get_physics_enabled(in_puppet_t *obj);

/**
    Sets whether to calculate physics for the puppet.

    Params:
        obj =   The puppet object.
        value = The value to set.
*/
void IN_CALL in_puppet_set_physics_enabled(in_puppet_t *obj, bool value);

/**
    Gets the pixel-to-meter unit mapping for the physics system.

    Params:
        obj = The puppet object.

    Returns:
        A value describing how many pixels count as a meter.
*/
float IN_CALL in_puppet_get_pixels_per_meter(in_puppet_t *obj);

/**
    Sets the pixel-to-meter unit mapping for the physics system.

    Params:
        obj =   The puppet object.
        value = The value to set.
*/
void IN_CALL in_puppet_set_pixels_per_meter(in_puppet_t *obj, float value);

/**
    Gets the gravity constant for the puppet.

    Params:
        obj = The puppet object.

    Returns:
        A value describing how many meters a second gravity
        pulls on the puppet. Normally is 9.8.
*/
float IN_CALL in_puppet_get_gravity(in_puppet_t *obj);

/**
    Sets the gravity constant for the puppet.

    Params:
        obj =   The puppet object.
        value = The value to set.
*/
void IN_CALL in_puppet_set_gravity(in_puppet_t *obj, float value);

/**
    Updates a puppet.

    Params:
        obj = The puppet object.
        delta = Time since last frame.
*/
void IN_CALL in_puppet_update(in_puppet_t *obj, float delta);

/**
    Draws a puppet.

    Params:
        obj = The puppet object.
        delta = Time since last frame.
*/
void IN_CALL in_puppet_draw(in_puppet_t *obj, float delta);

/**
    Resets the physics state for the puppet.

    Params:
        obj = The puppet object.
*/
void IN_CALL in_puppet_reset_drivers(in_puppet_t *obj);

/**
    Gets the root node of the puppet.

    Params:
        obj = The puppet object.

    Returns:
        The root node of the object.
*/
in_node_t *IN_CALL in_puppet_get_root_node(in_puppet_t *obj);

/**
    Gets the texture cache belonging to the puppet.

    Params:
        obj = The puppet object.

    Returns:
        The texture cache associated with the puppet.
*/
in_texture_cache_t *IN_CALL in_puppet_get_texture_cache(in_puppet_t *obj);

/**
    Gets the parameters of the puppet.

    Params:
        obj = The puppet object.
        count = Where to store the parameter element count.

    Returns:
        A puppet-owned array of parameters.
*/
in_parameter_t **IN_CALL in_puppet_get_parameters(in_puppet_t *obj, uint32_t *count);
/**
    Gets the puppet's draw list.

    Params:
        obj = The puppet object.

    Returns:
        The drawlist used by the puppet.
*/
in_drawlist_t *IN_CALL in_puppet_get_drawlist(in_puppet_t *obj);




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
const char *IN_CALL in_parameter_get_name(in_parameter_t *obj);

/**
    Gets whether the parameter is active.

    Params:
        obj = The parameter object.

    Returns:
        $(D true) if the parameter is active,
        $(D false) otherwise.
*/
bool IN_CALL in_parameter_get_active(in_parameter_t *obj);

/**
    Gets how many dimensions the parameter has.

    Params:
        obj = The parameter object.

    Returns:
        A number which indicates how many dimensions
        the parameter has.
*/
uint32_t IN_CALL in_parameter_get_dimensions(in_parameter_t *obj);

/**
    Gets the parameter's lower bounds.

    Params:
        obj = The parameter object.

    Returns:
        Pointer to a series of parameter-owned floats,
        use $(D in_parameter_get_dimensions) to get the dimensionality.
*/
const float *IN_CALL in_parameter_get_lower_bounds(in_parameter_t *obj);

/**
    Gets the parameter's upper bounds.

    Params:
        obj = The parameter object.

    Returns:
        Pointer to a series of parameter-owned floats,
        use $(D in_parameter_get_dimensions) to get the dimensionality.
*/
const float *IN_CALL in_parameter_get_upper_bounds(in_parameter_t *obj);

/**
    Gets the parameter's current value.

    Params:
        obj = The parameter object.

    Returns:
        Pointer to a series of parameter-owned floats,
        use $(D in_parameter_get_dimensions) to get the dimensionality.
*/
float *IN_CALL in_parameter_get_value(in_parameter_t *obj);

/**
    Sets the parameter's current value.

    Params:
        obj =       The parameter object.
        values =    The values to set for the parameter.
*/
void IN_CALL in_parameter_set_value(in_parameter_t *obj, float *values);




//
//              NODES
//

/**
    Creates a new basic node, optionally parented to the given node.

    Params:
        parent = The parent of the newly created node, or null.

    Returns:
        The newly allocated node.
*/
in_node_t *IN_CALL in_node_new(in_node_t *parent);
/**
    Gets the name of the node.

    Params:
        self = The node to operate on.

    Returns:
        The name of the node.
*/
const char *IN_CALL in_node_get_name(in_node_t *node);

/**
    Gets the type of the node.

    Params:
        self = The node to operate on.

    Returns:
        The type id of the node.
*/
const char *IN_CALL in_node_get_type(in_node_t *self);

/**
    Gets the GUID of a node.

    Params:
        self =  The node to operate on.

    Returns:
        A pointer to node-owned GUID data,
        $(D null) on failure.
*/
const in_guid_t *IN_CALL in_node_get_guid(in_node_t *self);

/**
    Gets the puppet that the node belongs to.

    Params:
        self = The node to operate on.

    Returns:
        The parent puppet or $(D null) if puppet is unrooted.
*/
in_puppet_t *IN_CALL in_node_get_puppet(in_node_t *self);

/**
    Gets the parent node of the given node.

    Params:
        self = The node to operate on.

    Returns:
        Pointer to the parent node, or $(D null)
        if the node is the root of its tree.
*/
in_node_t *IN_CALL in_node_get_parent(in_node_t *self);

/**
    Sets the parent of the given node.

    Params:
        self =      The node to operate on.
        parent =    The parent to set, or $(D null).
*/
void IN_CALL in_node_set_parent(in_node_t *self, in_node_t *parent);

/**
    Gets the child nodes of the given node.

    Params:
        self =  The node to operate on.
        count = Where to store the node count.

    Returns:
        A node-owned array of nodes.
*/
in_node_t **IN_CALL in_node_get_children(in_node_t *self, uint32_t *count);


/**
    Gets whether the node is enabled.

    Params:
        self = The node to operate on.

    Returns:
        $(D true) if the node is enabled,
        $(D false) otherwise.
*/
bool IN_CALL in_node_get_enabled(in_node_t *self);

/**
    Sets whether the node is enabled.

    Params:
        self =  The node to operate on.
        value = The value to set.
*/
void IN_CALL in_node_set_enabled(in_node_t *self, bool value);

/**
    Gets whether the node's transform is locked to the root
    node.

    Params:
        self = The node to operate on.

    Returns:
        $(D true) if the transformation of the node is locked
        to the root node, $(D false) otherwise.
*/
bool IN_CALL in_node_get_lock_to_root(in_node_t *self);

/**
    Sets whether the node's transform is locked to the root
    node.

    Params:
        self =  The node to operate on.
        value = The value to set.
*/
void IN_CALL in_node_set_lock_to_root(in_node_t *self, bool value);

/**
    Gets the depth of the node in the node tree.

    Params:
        self =  The node to operate on.

    Returns:
        The depth of the node in the tree.
*/
uint32_t IN_CALL in_node_get_tree_depth(in_node_t *self);

/**
    Gets whether the node has the given property.

    Params:
        self =  The node to operate on.
        key =   Name of the property to query.

    Returns:
        $(D true) if the node has the given property,
        $(D false) otherwise.
*/
bool IN_CALL in_node_has_property(in_node_t *self, quark_t key);

/**
    Gets the value of the given property.

    Params:
        self =  The node to operate on.
        key =   Name of the property to query.

    Returns:
        The value of the property.
*/
float IN_CALL in_node_get_property(in_node_t *self, quark_t key);

/**
    Gets the default value of the given property.

    Params:
        self =  The node to operate on.
        key =   Name of the property to query.

    Returns:
        The default value of the property.
*/
float IN_CALL in_node_get_property_default(in_node_t *self, quark_t key);

/**
    Sets the value of the given property.

    Params:
        self =  The node to operate on.
        key =   Name of the property to query.
        value = Value to assign the property to.

    Returns:
        The default value of the property.
*/
void IN_CALL in_node_set_property(in_node_t *self, quark_t key, float value);

/**
    Resets the value of the given property.

    Params:
        self =  The node to operate on.
        key =   Name of the property to query.
*/
void IN_CALL in_node_reset_property(in_node_t *self, quark_t key);

/**
    Resets the values of all properties in the node.

    Params:
        self =  The node to operate on.
*/
void IN_CALL in_node_reset_properties(in_node_t *self);

/**
    Gets all the property keys for the given node.

    Params:
        self =  The node to operate on.
        count = Variable to store the quark count in.

    Returns:
        A pointer to the key list of the node on success,
        $(D null) otherwise.
*/
const quark_t *IN_CALL in_node_get_properties(in_node_t *self, uint32_t *count);




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
uint32_t IN_CALL in_texture_cache_get_size(in_texture_cache_t *obj);

/**
    Gets a texture from the cache.

    Params:
        obj = The texture cache object.
        slot = The slot to get the texture from.

    Returns:
        The requested texture if found,
        otherwise $(D null).
*/
in_texture_t *IN_CALL in_texture_cache_get_texture(in_texture_cache_t *obj, uint32_t slot);

/**
    Gets a texture from the cache.

    Params:
        obj = The texture cache object.
        count = Where to store the texture count.

    Returns:
        A puppet-owned array of textures.
*/

in_texture_t **IN_CALL in_texture_cache_get_textures(in_texture_cache_t *obj, uint32_t *count);

/**
    Prunes the texture cache of unreferenced textures.

    Params:
        obj = The texture cache object.
*/
void IN_CALL in_texture_cache_prune(in_texture_cache_t *obj);




//
//              VISUALS
//

/**
    Casts the given node to a visual.

    Params:
        self =  The node to operate on.

    Returns:
        A $(D in_visual_t*) representing the Visual,
        $(D null) if the cast failed.
*/
in_visual_t *IN_CALL in_as_visual(in_node_t *self);

/**
    Gets whether the renderer should delegate
    rendering logic to the visual node.

    Params:
        self =  The visual to operate on.

    Returns:
        $(D true) if the visual is delegated,
        $(D false) otherwise.
*/
bool IN_CALL in_visual_get_is_delegated(in_visual_t *self);

/**
    Gets whether the node can be used as a
    source of masking operations.

    Params:
        self =  The visual to operate on.

    Returns:
        $(D true) if the visual can be used for masking,
        $(D false) otherwise.
*/
bool IN_CALL in_visual_get_is_masking(in_visual_t *self);

/**
    Gets the z-sorting value of the given visual.

    Params:
        self =  The visual to operate on.

    Returns:
        The z-sorting value of the visual.
*/
int IN_CALL in_visual_get_zsort(in_visual_t *self);

/**
    Sets the z-sorting value of the given visual.

    Params:
        self =  The visual to operate on.
        value = The value to set.
*/
void IN_CALL in_visual_set_zsort(in_visual_t *self, int value);

/**
    Gets the render-time z-sorting value for the
    given visual.

    Params:
        self =  The visual to operate on.

    Returns:
        The z-sorting value of the visual.
*/
int IN_CALL in_visual_get_zsort_render(in_visual_t *self);




//
//              PARTS
//

/**
    Casts the given node to a part.

    Params:
        self =  The node to operate on.

    Returns:
        A $(D in_part_t*) representing the part,
        $(D null) if the cast failed.
*/
in_part_t *IN_CALL in_as_part(in_node_t *self);

/**
    Gets the mesh of a part.

    Params:
        self =  The part to operate on.

    Returns:
        The mesh of the part if present,
        $(D null) otherwise.
*/
in_mesh_t *IN_CALL in_part_get_mesh(in_part_t *self);

/**
    Gets the blending mode of the given part.

    Params:
        self =  The part to operate on.

    Returns:
        The blending mode of the part.
*/
in_blend_mode_t IN_CALL in_part_get_blend_mode(in_part_t *self);

/**
    Sets the blending mode of the given part.

    Params:
        self =  The part to operate on.
        value = The value to set.
*/
void IN_CALL in_part_set_blend_mode(in_part_t *self, in_blend_mode_t value);

/**
    Gets the opacity of the given part.

    Params:
        self =  The part to operate on.

    Returns:
        The opacity of the part.
*/
float IN_CALL in_part_get_opacity(in_part_t *self);

/**
    Sets the opacity of the given part.

    Params:
        self =  The part to operate on.
        value = The value to set.
*/
void IN_CALL in_part_set_opacity(in_part_t *self, float value);

/**
    Gets the emission strength of the given part.

    Params:
        self =  The part to operate on.

    Returns:
        The opacity of the part.
*/
float IN_CALL in_part_get_emission(in_part_t *self);

/**
    Sets the emission strength of the given part.

    Params:
        self =  The part to operate on.
        value = The value to set.
*/
void IN_CALL in_part_set_emission(in_part_t *self, float value);

/**
    Adds a mesh effect to the part.

    Params:
        self =      The part to operate on.
        effect =    The mesh effect to add.
*/
void IN_CALL in_part_add_effect(in_part_t *self, in_mesh_effect_t *effect);

/**
    Removes a given mesh effect from the part.

    Params:
        self =      The part to operate on.
        effect =    The effect to remove.
*/
void IN_CALL in_part_remove_effect(in_part_t *self, in_mesh_effect_t *effect);

/**
    Gets the mesh effects attached to a node.

    Params:
        self =      The part to operate on.
        count = Variablt to store the effect count in.

    Returns:
        A Part-owned array of mesh effects.
*/
in_mesh_effect_t **IN_CALL in_node_part_get_mesh_effects(in_part_t *self, uint32_t *count);




//
//              ANIMATED PARTS
//

/**
    Casts the given node to a animated part.

    Params:
        self =  The node to operate on.

    Returns:
        A $(D in_animated_part_t*) representing the animated part,
        $(D null) if the cast failed.
*/
in_animated_part_t *IN_CALL in_as_animated_part(in_node_t *self);

// TODO: Add the API.




//
//              COMPOSITES
//

/**
    Casts the given node to a composite.

    Params:
        self =  The node to operate on.

    Returns:
        A $(D in_composite_t*) representing the composite,
        $(D null) if the cast failed.
*/
in_composite_t *IN_CALL in_as_composite(in_node_t *self);

/**
    Gets the blending mode of the given composite.

    Params:
        self =  The composite to operate on.

    Returns:
        The blending mode of the composite.
*/
in_blend_mode_t IN_CALL in_composite_get_blend_mode(in_composite_t *self);

/**
    Sets the blending mode of the given composite.

    Params:
        self =  The composite to operate on.
        value = The value to set.
*/
void IN_CALL in_composite_set_blend_mode(in_composite_t *self, in_blend_mode_t value);

/**
    Gets the opacity of the given composite.

    Params:
        self =  The composite to operate on.

    Returns:
        The opacity of the composite.
*/
float IN_CALL in_composite_get_opacity(in_composite_t *self);

/**
    Sets the opacity of the given composite.

    Params:
        self =  The composite to operate on.
        value = The value to set.
*/
void IN_CALL in_composite_set_opacity(in_composite_t *self, float value);




//
//              MASKS
//

/**
    Casts the given node to a mask.

    Params:
        self =  The node to operate on.

    Returns:
        A $(D in_mask_t*) representing the mask,
        $(D null) if the cast failed.
*/
in_mask_t *IN_CALL in_as_mask(in_node_t *self);

// TODO: Add the API.




//
//              SOLOS
//

/**
    Casts the given node to a solo.

    Params:
        self =  The node to operate on.

    Returns:
        A $(D in_solo_t*) representing the solo,
        $(D null) if the cast failed.
*/
in_solo_t *IN_CALL in_as_solo(in_node_t *self);

// TODO: Add the API.




//
//              DEFORMERS
//

/**
    Casts the given node to a deformer.

    Params:
        self =  The node to operate on.

    Returns:
        A $(D in_deformer_t*) representing the deformer,
        $(D null) if the cast failed.
*/
in_deformer_t *IN_CALL in_as_deformer(in_node_t *self);

// TODO: Add the API.




//
//              BONES
//

/**
    Casts the given node to a bone.

    Params:
        self =  The node to operate on.

    Returns:
        A $(D in_bone_t*) representing the bone,
        $(D null) if the cast failed.
*/
in_bone_t *IN_CALL in_as_bone(in_node_t *self);

// TODO: Add the API.




//
//              BONE MODIFIERS
//

/**
    Casts the given node to a bone modifier.

    Params:
        self =  The node to operate on.

    Returns:
        A $(D in_bone_modifier_t*) representing the solo,
        $(D null) if the cast failed.
*/
in_bone_modifier_t *IN_CALL in_as_bone_modifier(in_node_t *self);

// TODO: Add the API.




//
//              RESOURCES
//

/**
    Gets the length of the resource in bytes.

    Params:
        obj = The resource object.

    Returns:
        The length of the resource's GPU memory allocation
        in bytes.
*/
uint32_t IN_CALL in_resource_get_length(in_resource_t *obj);

/**
    Gets the renderer ID of the resource.

    Params:
        obj = The resource object.

    Returns:
        The renderer ID of the resource.
*/
void *IN_CALL in_resource_get_id(in_resource_t *obj);

/**
    Sets the renderer ID of the resource.

    Params:
        obj = The resource object.
        value = The value to set.
*/
void IN_CALL in_resource_set_id(in_resource_t *obj, void *value);




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
in_texture_t *IN_CALL in_texture_from_resource(in_resource_t *obj);

/**
    Gets the width of the texture in pixels.

    Params:
        obj = The texture object.

    Returns:
        The width of the texture in pixels.
*/
uint32_t IN_CALL in_texture_get_width(in_texture_t *obj);

/**
    Gets the height of the texture in pixels.

    Params:
        obj = The texture object.

    Returns:
        The height of the texture in pixels.
*/
uint32_t IN_CALL in_texture_get_height(in_texture_t *obj);

/**
    Gets the channels of the texture.

    Params:
        obj = The texture object.

    Returns:
        The channel count of the texture.
*/
uint32_t IN_CALL in_texture_get_channels(in_texture_t *obj);

/**
    Flips the texture's data vertically.
    Some engines read in a different direction from Inochi2D.

    Params:
        obj = The texture object.
*/
void IN_CALL in_texture_flip_vertically(in_texture_t *obj);

/**
    Premultiplies the alpha channel of the texture.

    Params:
        obj = The texture object.
*/
void IN_CALL in_texture_premultiply(in_texture_t *obj);

/**
    Un-premultiplies the alpha channel of the texture.

    Params:
        obj = The texture object.
*/
void IN_CALL in_texture_unpremultiply(in_texture_t *obj);

/**
    Pads the texture with a border.

    Params:
        obj =       The texture object.
        thickness = Thickness of the border in pixels.
*/
void IN_CALL in_texture_pad(in_texture_t *obj, uint32_t thickness);

/**
    Gets the pixels of the texture.

    Params:
        obj = The texture object.

    Returns:
        The pixels of the texture.
*/
void *IN_CALL in_texture_get_pixels(in_texture_t *obj);




//
//              DRAWLIST
//

/**
    Gets whether the draw list uses base vertex offsets.

    Params:
        obj = The drawlist

    Returns:
        $(D true) if base vertex offsets are being generated,
        $(D false) otherwise.
*/
bool IN_CALL in_drawlist_get_use_base_vertex(in_drawlist_t *obj);

/**
    Sets whether the draw list uses base vertex offsets.

    Params:
        obj =   The drawlist
        value = The value to set.
*/
void IN_CALL in_drawlist_set_use_base_vertex(in_drawlist_t *obj, bool value);

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
in_drawcmd_t *IN_CALL in_drawlist_get_commands(in_drawlist_t *obj, uint32_t *count);

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
in_vtxdata_t *IN_CALL in_drawlist_get_vertex_data(in_drawlist_t *obj, uint32_t *bytes);

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
void *IN_CALL in_drawlist_get_index_data(in_drawlist_t *obj, uint32_t *bytes);

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
in_drawalloc_t *IN_CALL in_drawlist_get_allocations(in_drawlist_t *obj, uint32_t *count);

#ifdef __cplusplus
}
#endif
#endif