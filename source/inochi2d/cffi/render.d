/**
    C FFI for rendering interface.

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.cffi.render;
import inochi2d.core.render;
import inochi2d.core.mesh;

version(IN_DYNLIB):
extern(C) export @nogc:

/**
    A resource that can be transferred between CPU and GPU.
*/
struct in_resource_t;

/**
    Resource is ready for use.
*/
enum IN_RESOURCE_STATUS_OK = 0;

/**
    A new resource should be created and an ID allocated to it
    by the rendering API.
*/
enum IN_RESOURCE_STATUS_WANTS_CREATE = 1;

/**
    A resource wants updates to its data or shape.
*/
enum IN_RESOURCE_STATUS_WANTS_UPDATE = 2;

/**
    A resource requests that it be deleted.
*/
enum IN_RESOURCE_STATUS_WANTS_DELETE = 3;

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
    A texture.
*/
struct in_texture_t;

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
enum in_drawstate_t
    IN_DRAW_STATE_NORMAL            = 0,
    IN_DRAW_STATE_DEFINE_MASK       = 1,
    IN_DRAW_STATE_MASKED_DRAW       = 2,
    IN_DRAW_STATE_COMPOSITE_BEGIN   = 3,
    IN_DRAW_STATE_COMPOSITE_END     = 4,
    IN_DRAW_STATE_COMPOSITE_BLIT    = 5;

/**
    Masking modes
*/
alias in_mask_mode_t = uint;
enum in_mask_mode_t
    IN_MASK_MODE_MASK   = 0,
    IN_MASK_MODE_DODGE  = 1;

/**
    Blending modes
*/
alias in_blend_mode_t = uint;
enum in_blend_mode_t
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
    IN_BLEND_MODE_CLIP_TO_LOWER     = 0x11,
    IN_BLEND_MODE_SLICE_FROM_LOWER  = 0x12;

/**
    A drawing command from the Inochi2D draw list
*/
struct in_drawcmd_t {
    in_texture_t*[IN_MAX_ATTACHMENTS]   sources;
    in_drawstate_t                      state;
    in_blend_mode_t                     blendMode;
    in_mask_mode_t                      maskMode;
    uint                                vtxOffset;
    uint                                idxOffset;
    uint                                elemCount;
    uint                                type;
    void[64]                            vars;
}

/**
    A drawlist instance
*/
struct in_drawlist_t;

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
void* in_drawlist_get_vertex_data(in_drawlist_t* obj, ref uint bytes) {
    bytes = cast(uint)((cast(DrawList)obj).vertices.length*VtxData.sizeof);
    return cast(void*)(cast(DrawList)obj).vertices.ptr;
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
    bytes = cast(uint)((cast(DrawList)obj).indices.length*uint.sizeof);
    return cast(void*)(cast(DrawList)obj).indices.ptr;
}