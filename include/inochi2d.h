#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifndef H_INOCHI2D
#define H_INOCHI2D

// Handle calling convention on Windows.
// This will ensure MSVC does not try to use stdcall
// when the D library uses cdecl.
#ifdef _WIN32
    #ifdef _MSC_VER
        #define I2D_CALL __cdecl
    #else
        #define I2D_CALL
    #endif
#else
    #define I2D_CALL
#endif

#define IN_MAX_ATTACHMENTS 8

#ifdef __cplusplus
extern "C" {
#endif

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

//
//          OPAQUE TYPES
//

/**
    Opaque handle to a puppet.
*/
typedef struct in_puppet_t in_puppet_t;

/**
    A texture cache.
*/
typedef struct in_texture_cache_t in_texture_cache_t;

/**
    A parameter.
*/
typedef struct in_parameter_t in_parameter_t;

/**
    A resource that can be transferred between CPU and GPU.
*/
typedef struct in_resource_t in_resource_t;

/**
    A texture.
*/
typedef struct in_texture_t in_texture_t;

/**
    A drawlist instance
*/
typedef struct in_drawlist_t in_drawlist_t;


/**
    Retains a reference to a Inochi2D Object.

    Params:
        obj = The object to retain.
    
    Returns:
        The object.
*/
void* I2D_CALL in_retain(void* obj);

/**
    Releases a reference to a Inochi2D Object.

    Params:
        obj = The object to release.
    
    Returns:
        The object.
*/
void* I2D_CALL in_release(void* obj);

/**
    Gets the last error.

    Returns:
        A string with the last error that occured,
        or $(D null).
*/
const char* I2D_CALL in_get_last_error();

//
//              PUPPET
//

/**
    Loads a puppet into memory.

    Params:
        file = The file to load.
    
    Returns:
        A new puppet instance, or $(D null) on failure.
    
    See_Also:
        $(D in_get_last_error)
*/
in_puppet_t* I2D_CALL in_puppet_load(const char* file);

/**
    Loads a puppet into memory.

    Params:
        data = The data of the puppet.
        length = The length of that data in bytes.
    
    Returns:
        A new puppet instance, or $(D null) on failure.
    
    See_Also:
        $(D in_get_last_error)
*/
in_puppet_t* I2D_CALL in_puppet_load_from_memory(const uint8_t* data, uint32_t length);

/**
    Frees a puppet from memory.

    Notes:
        The main Inochi2D type hirearchy hasn't been converted
        to numem types yet, as such this simply unpins it
        from the D GC.

    Params:
        obj = The puppet object.
*/
void I2D_CALL in_puppet_free(in_puppet_t* obj);

/**
    Gets the name of a puppet.

    Params:
        obj = The puppet object.

    Returns:
        The name of the puppet as specified by
        its author.
*/
const char* I2D_CALL in_puppet_get_name(in_puppet_t* obj);

/**
    Gets whether to calculate physics for the puppet.

    Params:
        obj = The puppet object.

    Returns:
        Whether physics are enabled.
*/
bool I2D_CALL in_puppet_get_physics_enabled(in_puppet_t* obj);

/**
    Sets whether to calculate physics for the puppet.

    Params:
        obj =   The puppet object.
        value = The value to set.
*/
void I2D_CALL in_puppet_set_physics_enabled(in_puppet_t* obj, bool value);

/**
    Gets the pixel-to-meter unit mapping for the physics system.

    Params:
        obj = The puppet object.

    Returns:
        A value describing how many pixels count as a meter.
*/
float I2D_CALL in_puppet_get_pixels_per_meter(in_puppet_t* obj);

/**
    Sets the pixel-to-meter unit mapping for the physics system.

    Params:
        obj =   The puppet object.
        value = The value to set.
*/
void I2D_CALL in_puppet_set_pixels_per_meter(in_puppet_t* obj, float value);

/**
    Gets the gravity constant for the puppet.

    Params:
        obj = The puppet object.

    Returns:
        A value describing how many meters a second gravity
        pulls on the puppet. Normally is 9.8.
*/
float I2D_CALL in_puppet_get_gravity(in_puppet_t* obj);

/**
    Sets the gravity constant for the puppet.

    Params:
        obj =   The puppet object.
        value = The value to set.
*/
void I2D_CALL in_puppet_set_gravity(in_puppet_t* obj, float value);

/**
    Updates a puppet.

    Params:
        obj = The puppet object.
        delta = Time since last frame.
*/
void I2D_CALL in_puppet_update(in_puppet_t* obj, float delta);

/**
    Draws a puppet.

    Params:
        obj = The puppet object.
        delta = Time since last frame.
*/
void I2D_CALL in_puppet_draw(in_puppet_t* obj, float delta);

/**
    Resets the physics state for the puppet.

    Params:
        obj = The puppet object.
*/
void I2D_CALL in_puppet_reset_drivers(in_puppet_t* obj);

/**
    Gets the texture cache belonging to the puppet.

    Params:
        obj = The puppet object.
    
    Returns:
        The texture cache associated with the puppet.
*/
in_texture_cache_t* I2D_CALL in_puppet_get_texture_cache(in_puppet_t* obj);

/**
    Gets the parameters of the puppet.

    Params:
        obj = The puppet object.
        count = Where to store the parameter element count.
    
    Returns:
        A puppet-owned array of parameters.
*/
in_parameter_t** I2D_CALL in_puppet_get_parameters(in_puppet_t* obj, uint32_t* count);
/**
    Gets the puppet's draw list.

    Params:
        obj = The puppet object.
    
    Returns:
        The drawlist used by the puppet.
*/
in_drawlist_t* I2D_CALL in_puppet_get_drawlist(in_puppet_t* obj);

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
const char* I2D_CALL in_parameter_get_name(in_parameter_t* obj);

/**
    Gets whether the parameter is active.
    
    Params:
        obj = The parameter object.
    
    Returns:
        $(D true) if the parameter is active,
        $(D false) otherwise.
*/
bool I2D_CALL in_parameter_get_active(in_parameter_t* obj);

/**
    Gets how many dimensions the parameter has.
    
    Params:
        obj = The parameter object.
    
    Returns:
        A number which indicates how many dimensions
        the parameter has.
*/
uint32_t I2D_CALL in_parameter_get_dimensions(in_parameter_t* obj);

/**
    Gets the parameter's minimum value.
    
    Params:
        obj = The parameter object.
    
    Returns:
        The parameter's minimum value.
*/
in_vec2_t I2D_CALL in_parameter_get_min_value(in_parameter_t* obj);

/**
    Gets the parameter's maximum value.
    
    Params:
        obj = The parameter object.
    
    Returns:
        The parameter's maximum value.
*/
in_vec2_t I2D_CALL in_parameter_get_max_value(in_parameter_t* obj);

/**
    Gets the parameter's current value.
    
    Params:
        obj = The parameter object.
    
    Returns:
        The parameter's current value.
*/
in_vec2_t I2D_CALL in_parameter_get_value(in_parameter_t* obj);

/**
    Sets the parameter's current value.
    
    Params:
        obj =   The parameter object.
        value = The value to set.
*/
void I2D_CALL in_parameter_set_value(in_parameter_t* obj, in_vec2_t value);

/**
    Gets the parameter's current value normalized to
    a range of 0..1
    
    Params:
        obj = The parameter object.
    
    Returns:
        The parameter's current normalized value.
*/
in_vec2_t I2D_CALL in_parameter_get_normalized_value(in_parameter_t* obj);

/**
    Sets the parameter's current value normalized to
    a range of 0..1
    
    Params:
        obj =   The parameter object.
        value = The value to set.
*/
void I2D_CALL in_parameter_set_normalized_value(in_parameter_t* obj, in_vec2_t value);

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
uint32_t I2D_CALL in_texture_cache_get_size(in_texture_cache_t* obj);

/**
    Gets a texture from the cache.

    Params:
        obj = The texture cache object.
        slot = The slot to get the texture from.

    Returns:
        The requested texture if found,
        otherwise $(D null).
*/
in_texture_t* I2D_CALL in_texture_cache_get_texture(in_texture_cache_t* obj, uint32_t slot);

/**
    Gets a texture from the cache.

    Params:
        obj = The texture cache object.
        count = Where to store the texture count.

    Returns:
        A puppet-owned array of textures.
*/

in_texture_t** I2D_CALL in_texture_cache_get_textures(in_texture_cache_t* obj, uint32_t* count);

/**
    Prunes the texture cache of unreferenced textures.

    Params:
        obj = The texture cache object.
*/
void I2D_CALL in_texture_cache_prune(in_texture_cache_t* obj);

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
uint32_t I2D_CALL in_resource_get_length(in_resource_t* obj);
/**
    Gets the renderer ID of the resource.

    Params:
        obj = The resource object.
    
    Returns:
        The renderer ID of the resource.
*/
void* I2D_CALL in_resource_get_id(in_resource_t* obj);

/**
    Sets the renderer ID of the resource.

    Params:
        obj = The resource object.
        value = The value to set.
*/
void I2D_CALL in_resource_set_id(in_resource_t* obj, void* value);

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
in_texture_t* I2D_CALL in_texture_from_resource(in_resource_t* obj);

/**
    Gets the width of the texture in pixels.

    Params:
        obj = The texture object.

    Returns:
        The width of the texture in pixels.
*/
uint32_t I2D_CALL in_texture_get_width(in_texture_t* obj);

/**
    Gets the height of the texture in pixels.

    Params:
        obj = The texture object.

    Returns:
        The height of the texture in pixels.
*/
uint32_t I2D_CALL in_texture_get_height(in_texture_t* obj);

/**
    Gets the channels of the texture.

    Params:
        obj = The texture object.

    Returns:
        The channel count of the texture.
*/
uint32_t I2D_CALL in_texture_get_channels(in_texture_t* obj);

/**
    Flips the texture's data vertically.
    Some engines read in a different direction from Inochi2D.

    Params:
        obj = The texture object.
*/
void I2D_CALL in_texture_flip_vertically(in_texture_t* obj);

/**
    Premultiplies the alpha channel of the texture.

    Params:
        obj = The texture object.
*/
void I2D_CALL in_texture_premultiply(in_texture_t* obj);

/**
    Un-premultiplies the alpha channel of the texture.

    Params:
        obj = The texture object.
*/
void I2D_CALL in_texture_unpremultiply(in_texture_t* obj);

/**
    Pads the texture with a border.

    Params:
        obj =       The texture object.
        thickness = Thickness of the border in pixels.
*/
void I2D_CALL in_texture_pad(in_texture_t* obj, uint32_t thickness);

/**
    Gets the pixels of the texture.

    Params:
        obj = The texture object.

    Returns:
        The pixels of the texture.
*/
void* I2D_CALL in_texture_get_pixels(in_texture_t* obj);

//
//              DRAWLIST
//

/**
    DrawState flags
*/
typedef enum {
    IN_DRAW_STATE_NORMAL            = 0,
    IN_DRAW_STATE_DEFINE_MASK       = 1,
    IN_DRAW_STATE_MASKED_DRAW       = 2,
    IN_DRAW_STATE_COMPOSITE_BEGIN   = 3,
    IN_DRAW_STATE_COMPOSITE_END     = 4,
    IN_DRAW_STATE_COMPOSITE_BLIT    = 5,
    IN_DRAW_STATE_MAX               = 0xFFFFFFFFU
} in_drawstate_t;

/**
    Masking modes
*/
typedef enum {
    IN_MASK_MODE_MASK   = 0,
    IN_MASK_MODE_DODGE  = 1,
    IN_MASK_MODE_MAX    = 0xFFFFFFFFU
} in_mask_mode_t;

/**
    Blending modes
*/
typedef enum {
    IN_BLEND_MODE_NORMAL            = 0x00,
    IN_BLEND_MODE_MULTIPLY          = 0x01,
    IN_BLEND_MODE_SCREEN            = 0x02,
    IN_BLEND_MODE_OVERLAY           = 0x03,
    IN_BLEND_MODE_DARKEN            = 0x04,
    IN_BLEND_MODE_LIGHTEN           = 0x05,
    IN_BLEND_MODE_COLOR_DODGE       = 0x06,
    IN_BLEND_MODE_LINEAR_DODGE      = 0x07,
    IN_BLEND_MODE_ADD_GLOW          = 0x08,
    IN_BLEND_MODE_COLOR_BURN        = 0x09,
    IN_BLEND_MODE_HARD_LIGHT        = 0x0A,
    IN_BLEND_MODE_SOFT_LIGHT        = 0x0B,
    IN_BLEND_MODE_DIFFERENCE        = 0x0C,
    IN_BLEND_MODE_EXCLUSION         = 0x0D,
    IN_BLEND_MODE_SUBTRACT          = 0x0E,
    IN_BLEND_MODE_INVERSE           = 0x0F,
    IN_BLEND_MODE_DESTINATION_IN    = 0x10,
    IN_BLEND_MODE_SOURCE_IN         = 0x11,
    IN_BLEND_MODE_SOURCE_OUT        = 0x12,
    IN_BLEND_MODE_MAX               = 0xFFFFFFFFU
} in_blend_mode_t;

/**
    A drawing command from the Inochi2D draw list
*/
typedef struct in_drawcmd_t {
    in_texture_t*                       sources[IN_MAX_ATTACHMENTS];
    in_drawstate_t                      state;
    in_blend_mode_t                     blendMode;
    in_mask_mode_t                      maskMode;
    uint32_t                            allocId;
    uint32_t                            vtxOffset;
    uint32_t                            idxOffset;
    uint32_t                            elemCount;
    uint32_t                            type;
    unsigned char                       vars[64];
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

/**
    Gets whether the draw list uses base vertex offsets.

    Params:
        obj = The drawlist
    
    Returns:
        $(D true) if base vertex offsets are being generated,
        $(D false) otherwise.
*/
bool I2D_CALL in_drawlist_get_use_base_vertex(in_drawlist_t* obj);

/**
    Sets whether the draw list uses base vertex offsets.

    Params:
        obj =   The drawlist
        value = The value to set.
*/
void I2D_CALL in_drawlist_set_use_base_vertex(in_drawlist_t* obj, bool value);

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
in_drawcmd_t* I2D_CALL in_drawlist_get_commands(in_drawlist_t* obj, uint32_t* count);

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
in_vtxdata_t* I2D_CALL in_drawlist_get_vertex_data(in_drawlist_t* obj, uint32_t* bytes);

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
void* I2D_CALL in_drawlist_get_index_data(in_drawlist_t* obj, uint32_t* bytes);

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
in_drawalloc_t* I2D_CALL in_drawlist_get_allocations(in_drawlist_t* obj, uint32_t* count);

#ifdef __cplusplus
}
#endif
#endif