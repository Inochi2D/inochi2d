/**
    C FFI for puppets.

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.cffi.puppet;
import inochi2d.cffi.render;
import inochi2d.cffi.eh;
import inochi2d.core.puppet;
import inochi2d.core.render;
import inochi2d.core.format;
import inochi2d.core.param;
import numem;
import nulib.string;
import inochi2d.cffi;
import inmath;

extern(C) export @nogc:

//
//              PUPPET
//

/**
    Opaque handle to a puppet.
*/
struct in_puppet_t;

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
    import core.memory : GC;

    __in_clear_error();

    string path = cast(string)file[0..nu_strlen(file)];
    return cast(in_puppet_t*)assumeNoGC((string file) {
        try {
            Puppet p = assumeNoGC(&inLoadPuppet!Puppet, file);
            GC.addRoot(cast(void*)p);
            return p;
        } catch (Exception ex) {
            __in_set_error(ex);
            return null;
        }
    }, path);
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
    import core.memory : GC;
    
    __in_clear_error();

    return cast(in_puppet_t*)assumeNoGC((ubyte[] buffer) {
        try {
            Puppet p = assumeNoGC(&inLoadINPPuppet!Puppet, buffer);
            GC.addRoot(cast(void*)p);
            return p;
        } catch (Exception ex) {
            __in_set_error(ex);
            return null;
        }
    }, cast(ubyte[])data[0..length]);
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
    import core.memory : GC;
    if (obj) {
        GC.removeRoot(cast(void*)obj);
    }
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
    return (cast(Parameter)obj).isVec2+1;
}

/**
    Gets the parameter's minimum value.
    
    Params:
        obj = The parameter object.
    
    Returns:
        The parameter's minimum value.
*/
in_vec2_t in_parameter_get_min_value(in_parameter_t* obj) {
    return reinterpret_cast!in_vec2_t((cast(Parameter)obj).min);
}

/**
    Gets the parameter's maximum value.
    
    Params:
        obj = The parameter object.
    
    Returns:
        The parameter's maximum value.
*/
in_vec2_t in_parameter_get_max_value(in_parameter_t* obj) {
    return reinterpret_cast!in_vec2_t((cast(Parameter)obj).max);
}

/**
    Gets the parameter's current value.
    
    Params:
        obj = The parameter object.
    
    Returns:
        The parameter's current value.
*/
in_vec2_t in_parameter_get_value(in_parameter_t* obj) {
    return reinterpret_cast!in_vec2_t((cast(Parameter)obj).value);
}

/**
    Sets the parameter's current value.
    
    Params:
        obj =   The parameter object.
        value = The value to set.
*/
void in_parameter_set_value(in_parameter_t* obj, in_vec2_t value) {
    (cast(Parameter)obj).value = reinterpret_cast!vec2(value);
}

/**
    Gets the parameter's current value normalized to
    a range of 0..1
    
    Params:
        obj = The parameter object.
    
    Returns:
        The parameter's current normalized value.
*/
in_vec2_t in_parameter_get_normalized_value(in_parameter_t* obj) {
    return reinterpret_cast!in_vec2_t((cast(Parameter)obj).normalizedValue);
}

/**
    Sets the parameter's current value normalized to
    a range of 0..1
    
    Params:
        obj =   The parameter object.
        value = The value to set.
*/
void in_parameter_set_normalized_value(in_parameter_t* obj, in_vec2_t value) {
    (cast(Parameter)obj).normalizedValue = reinterpret_cast!vec2(value);
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