/**
    C FFI for rendering interface.

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.cffi.render;
import inochi2d.core.render;

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
    Gets the status of the resource.

    Params:
        obj = The resource object.
    
    Returns:
        The status of the object.
*/
uint in_resource_get_status(in_resource_t* obj) {
    return cast(uint)(cast(Resource)obj).status;
}

/**
    Sets the status of the resource.

    Params:
        obj = The resource object.
        value = The value to set.
*/
void in_resource_set_status(in_resource_t* obj, uint value) {
    (cast(Resource)obj).status = cast(ResourceStatus)value;
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

/**
    Finalizes a resource update.

    Params:
        obj = The resource object.
*/
void in_resource_finalize(in_resource_t* obj) {
    (cast(Resource)obj).finalize();
}