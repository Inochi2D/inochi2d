/**
    C FFI for puppets.

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.cffi.puppet;
import inochi2d.cffi.render;
import inochi2d.core.puppet;
import inochi2d.core.render;
import inochi2d.core.format;
import numem;
import nulib.string;

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
*/
in_puppet_t* in_puppet_load(const(char)* file) {
    import core.memory : GC;

    string path = cast(string)file[0..nu_strlen(file)];
    return cast(in_puppet_t*)assumeNoGC((string file) {
        Puppet p = assumeNoGC(&inLoadPuppet!Puppet, file);
        GC.addRoot(cast(void*)p);
        return p;
    }, path);
}

/**
    Loads a puppet into memory.

    Params:
        data = The data of the puppet.
        length = The length of that data in bytes.
    
    Returns:
        A new puppet instance, or $(D null) on failure.
*/
in_puppet_t* in_puppet_load_from_memory(const(ubyte)* data, uint length) {
    import core.memory : GC;
    return cast(in_puppet_t*)assumeNoGC((ubyte[] buffer) {
        Puppet p = assumeNoGC(&inLoadINPPuppet!Puppet, buffer);
        GC.addRoot(cast(void*)p);
        return p;
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
    Gets the texture cache belonging to the puppet.

    Params:
        obj = The puppet object.
    
    Returns:
        The texture cache associated with the puppet.
*/
in_texture_cache_t* in_puppet_get_texture_cache(in_puppet_t* obj) {
    return cast(in_texture_cache_t*)(cast(Puppet)obj).textureCache;
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
    Prunes the texture cache of unreferenced textures.

    Params:
        obj = The texture cache object.
*/
void in_texture_cache_prune(in_texture_cache_t* obj) {
    (cast(TextureCache)obj).prune();
}