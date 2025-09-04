/**
    C FFI for rendering interface.

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.cffi.render;
import inochi2d.core.render;

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