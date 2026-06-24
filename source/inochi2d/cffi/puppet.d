/**
    C FFI for puppets.

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.cffi.puppet;
import inochi2d.cffi.render;
import inochi2d.cffi.nodes;
import inochi2d.cffi.eh;
import inochi2d.puppet;
import inochi2d.param;
import inochi2d.core;
import inochi2d.cffi;
import nulib.string;
import numath;
import numem;

version (IN_DYNLIB) :
extern (C) export @nogc:

//
//              PUPPET
//

/**
    Opaque handle to a puppet.
*/
struct in_puppet_t;

version (WebAssembly) {
} else {
    /**
        Loads a puppet into memory.

        Params:
            file = The file to load.
        
        Returns:
            A new puppet instance, or $(D null) on failure.
        
        See_Also:
            $(D in_get_last_error)
    */
    in_puppet_t* in_puppet_load(const(char)* file) {
        import nulib.string : fromStringz;

        __in_clear_error();
        return cast(in_puppet_t*)Puppet.fromFile(cast(string)file.fromStringz);
    }
}

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
in_puppet_t* in_puppet_load_from_memory(const(ubyte)* data, uint length) {
    import nulib.io.stream : MemoryStream;

    __in_clear_error();
    auto stream = nogc_new!MemoryStream(cast(ubyte[])data[0..length]);
    scope(exit) {
        stream.take();
        nogc_delete(stream);
    }

    auto result = Puppet.fromStream(stream);
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
    assumeNoThrowNoGC(&(cast(Puppet)obj).update, delta);
}

/**
    Draws a puppet.

    Params:
        obj = The puppet object.
        delta = Time since last frame.
*/
void in_puppet_draw(in_puppet_t* obj, float delta) {
    assumeNoThrowNoGC(&(cast(Puppet)obj).draw, delta);
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

//
//              PARAMETERS
//

struct in_parameter_t;

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
    (cast(Parameter)obj).currentValue[0..dims] = values[0..dims];
}




//
//              TEXTURE CACHE
//

/**
    A texture cache.
*/
struct in_texture_cache_t;

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
