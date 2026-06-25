//
//          GLOBAL INOCHI2D LIBRARY INSTANCE.
//
var __inochi2d = {
    module: null,
    instance: null,
    nu_malloc: null,
    nu_free: null,
    __scratchpad: null,
    __import_object: {
        env: {
            STACKTOP: 0,
            STACK_MAX:65536,
            abortStackOverflow: function(val) { throw new Error("stack overfow"); },
            memory: new WebAssembly.Memory( { initial: 256 } ),
            table: new WebAssembly.Table( { initial:0, maximum:0, element: "anyfunc" } ),
            memoryBase:0,
            tableBase:0
        },
        wasi_snapshot_preview1: {
            args_get() { return 0; },
            args_sizes_get() { return 0; },
            path_open() { return 0; },
            fd_close() { return 0; },
            fd_seek() { return 0; },
            fd_read() { return 0; },
            fd_write() { return 0; },
            fd_fdstat_get() { return 0; },
            fd_fdstat_set_flags() { return 0; },
            fd_prestat_get() { return 0; },
            fd_prestat_dir_name() { return 0; },
            proc_exit() { return 0; },
        }
    }
};

/**
    Initializes Inochi2D with an optional module path.

    If none are selected, it is assumed that the inochi2d wasm
    module is placed next to the wrapper JS file.    
*/
async function in_init(url = "inochi2d.wasm") {
    try {
        let result = await WebAssembly.instantiateStreaming(fetch(url), __inochi2d.__import_object);
        __inochi2d.module = result.module;
        __inochi2d.instance = result.instance;
        __inochi2d.instance.exports._start();
        __inochi2d.nu_malloc = __inochi2d.instance.exports.nu_malloc;
        __inochi2d.nu_free = __inochi2d.instance.exports.nu_free;
        __inochi2d.scratchpad = __inochi2d.nu_malloc(128);
    } catch(error) {
        throw error;
    }
}




//
//      CONSTANTS
//

// Max amount of attachments.
const IN_MAX_ATTACHMENTS = 8;

// Size of the in_drawalloc_t type
const IN_DRAWALLOC_SIZE = 4*5;

// Size of the in_drawcmd_t type
const IN_DRAWCMD_SIZE = 
    (4*IN_MAX_ATTACHMENTS) +    // sources
    4 +                         // state
    4 +                         // blendMode
    4 +                         // maskMode
    4 +                         // allocId
    4 +                         // vtxOffset
    4 +                         // idxOffset
    4 +                         // elemCount
    4 +                         // type
    64;                         // vars

// Dimensions stored in the vertex data.
const IN_VTXDATA_DIMS = 2;

// Size of a vtxdata_t
const IN_VTXDATA_SIZE = 
    (IN_VTXDATA_DIMS * 4) +     // xy(z)
    (2 * 4);                    // uv

// Byte offset of the UV coordinates.
const IN_VTXDATA_UV_OFFSET =
    (IN_VTXDATA_DIMS * 4);     // xy(z)

const IN_DRAW_STATE_NORMAL = 0;
const IN_DRAW_STATE_DEFINE_MASK = 1;
const IN_DRAW_STATE_MASKED_DRAW = 2;
const IN_DRAW_STATE_COMPOSITE_BEGIN = 3;
const IN_DRAW_STATE_COMPOSITE_END = 4;
const IN_DRAW_STATE_COMPOSITE_BLIT = 5;

const IN_MASK_MODE_MASK = 0;
const IN_MASK_MODE_DODGE = 0;

const IN_BLEND_MODE_NORMAL = 0x00;
const IN_BLEND_MODE_MULTIPLY = 0x01;
const IN_BLEND_MODE_SCREEN = 0x02;
const IN_BLEND_MODE_OVERLAY = 0x03;
const IN_BLEND_MODE_DARKEN = 0x04;
const IN_BLEND_MODE_LIGHTEN = 0x05;
const IN_BLEND_MODE_COLOR_DODGE = 0x06;
const IN_BLEND_MODE_LINEAR_DODGE = 0x07;
const IN_BLEND_MODE_ADD_GLOW = 0x08;
const IN_BLEND_MODE_COLOR_BURN = 0x09;
const IN_BLEND_MODE_HARD_LIGHT = 0x0A;
const IN_BLEND_MODE_SOFT_LIGHT = 0x0B;
const IN_BLEND_MODE_DIFFERENCE = 0x0C;
const IN_BLEND_MODE_EXCLUSION = 0x0D;
const IN_BLEND_MODE_SUBTRACT = 0x0E;
const IN_BLEND_MODE_INVERSE = 0x0F;
const IN_BLEND_MODE_DESTINATION_IN = 0x10;
const IN_BLEND_MODE_SOURCE_IN = 0x11;
const IN_BLEND_MODE_SOURCE_OUT = 0x12;




//
//      HELPERS
//

/**
    Helper that gets the length of a wasm string.    
*/
function strlen_nz(ptr) {
    let wasm_view = new DataView(__inochi2d.instance.exports.memory.buffer, ptr);
    for (let i = 0; i < wasm_view.byteLength; i++) {
        if (wasm_view.getUint8(i) == 0)
            return i;
    }
    return -1;
}

/**
    Helper function that convers the given D string to a JS string.    
*/
function fromDString(ptr, len) {
    if (ptr == 0)
        return "";

    let str_view = new DataView(__inochi2d.instance.exports.memory.buffer, ptr, len);
    const decoder = new TextDecoder('utf-8'); // D always produces UTF-8 strings.
    return decoder.decode(str_view);
}

/**
    Helper function that convers the given C string to a JS string.    
*/
function fromCString(ptr) {
    if (ptr == 0)
        return "";

    let str_view = new DataView(__inochi2d.instance.exports.memory.buffer, ptr, strlen_nz(ptr));
    const decoder = new TextDecoder('utf-8'); // D always produces UTF-8 strings.
    return decoder.decode(str_view);
}

/**
    Reads a drawing command at the given pointer.    
*/
function read_drawcmd(ptr) {
    const dv = new DataView(__inochi2d.instance.exports.memory.buffer, ptr, IN_DRAWCMD_SIZE);
    const data_start = 4*IN_MAX_ATTACHMENTS;
    let result = {
        sources:    new Uint32Array(IN_MAX_ATTACHMENTS),
        state:      dv.getUint32(data_start, true),
        blend_mode: dv.getUint32(data_start+4, true),
        mask_mode:  dv.getUint32(data_start+8, true),
        alloc_id:   dv.getUint32(data_start+12, true),
        vtx_offset: dv.getUint32(data_start+16, true),
        idx_offset: dv.getUint32(data_start+20, true),
        elem_count: dv.getUint32(data_start+24, true),
        type:       dv.getUint32(data_start+28, true),
        vars:       new DataView(__inochi2d.instance.exports.memory.buffer, ptr+data_start+32, 64)
    };

    // Populate texture sources.
    for (let i = 0; i < IN_MAX_ATTACHMENTS; i++) {
        let ptr = dv.getUint32(i*4, true);
        result.sources[i] = __inochi2d.instance.exports.in_resource_get_id(ptr);
    }

    return result;
}

/**
    Reads a draw-allocation from the given pointer.    
*/
function read_drawalloc(ptr) {
    const dv = new DataView(__inochi2d.instance.exports.memory.buffer, ptr, IN_DRAWALLOC_SIZE);
    return {
        vtx_offset: dv.getUint32(0, true),
        idx_offset: dv.getUint32(4, true),
        idx_count:  dv.getUint32(8, true),
        vtx_count:  dv.getUint32(12, true),
        alloc_id:   dv.getUint32(16, true),
    }
}

/**
    Helper that gets an unsigned integer from scratchpad memory.      
*/
function sp_get_uint32() {
    const view = new DataView(__inochi2d.instance.exports.memory.buffer);
    return view.getUint32(__inochi2d.scratchpad, true);
}



//
//          PUBLIC API
//

/**
    An Inochi2D puppet.    
*/
class InPuppet {
    #ptr;
    #textures;
    #drawlist;

    // Private helper function that gets the textures
    // of the model from the texture cache.
    #loadTextures() {
        let cache = __inochi2d.instance.exports.in_puppet_get_texture_cache(this.#ptr);
        let texarr = __inochi2d.instance.exports.in_texture_cache_get_textures(cache, __inochi2d.scratchpad);
        let count = sp_get_uint32();

        let texview = new DataView(__inochi2d.instance.exports.memory.buffer, texarr);
        this.#textures = new Array();
        for (let i = 0; i < count; i++) {
            this.#textures.push(new InTexture(texview.getUint32(i*4, true)));
        }
    }

    // Destructor
    [Symbol.dispose]() {
        __inochi2d.instance.exports.in_puppet_free(this.#ptr);
    }

    /**
        Constructs a puppet from a pointer.
    */
    constructor(ptr) {
        this.#ptr = ptr;
        this.#drawlist = new InDrawList(__inochi2d.instance.exports.in_puppet_get_drawlist(this.#ptr));
        this.#loadTextures();
    }

    /**
        Creates a puppet from a url, returning a promise.
    */
    static fromUrl(url) {
        return new Promise((resolve, reject) => {
            try {
                const data = fetch(url)
                .then((response) => response.bytes())
                .then((data) => {
                    let wptr = __inochi2d.nu_malloc(data.byteLength);
                    let wasm_view = new DataView(__inochi2d.instance.exports.memory.buffer);

                    for (let i = 0; i < data.byteLength; i++) {
                        wasm_view.setUint8(wptr+i, data[i]);
                    }

                    let ptr = __inochi2d.instance.exports.in_puppet_load_from_memory(wptr, data.byteLength);
                    __inochi2d.nu_free(wptr);
                    resolve(new InPuppet(ptr));
                });
            } catch(error) {
                reject(error);
            }
        });
    }

    /**
        Pointer to the underlying web-assembly data.
    */
    get ptr() { return this.#ptr; }

    /**
        The name of the puppet.
    */
    get name() {
        return fromCString(__inochi2d.instance.exports.in_puppet_get_name(this.#ptr));
    }

    /**
        The author of the puppet.
    */
    get author() {
        return fromCString(__inochi2d.instance.exports.in_puppet_get_author(this.#ptr));
    }

    /**
        The draw-list for the puppet.
    */
    get drawList() { return this.#drawlist; }

    /**
        The textures loaded for the puppet.
    */
    get textures() { return this.#textures; }

    /**
        Whether physics is enabled.
    */
    get physicsEnabled() { return __inochi2d.instance.exports.in_puppet_get_physics_enabled(this.#ptr) != 0; }
    set physicsEnabled(value) { __inochi2d.instance.exports.in_puppet_set_physics_enabled(this.#ptr, value); }

    /**
        The pixels-per-meter mapping for physics
    */
    get pixelsPerMeter() { return __inochi2d.instance.exports.in_puppet_get_pixels_per_meter(this.#ptr); }
    set pixelsPerMeter(value) { __inochi2d.instance.exports.in_puppet_set_pixels_per_meter(this.#ptr, value); }

    /**
        The gravity constant for the puppet, in meters-per-second.
    */
    get gravity() { return __inochi2d.instance.exports.in_puppet_get_gravity(this.#ptr); }
    set gravity(value) { __inochi2d.instance.exports.in_puppet_set_gravity(this.#ptr, value); }

    /**
        Updates the puppet.
    */
    update(delta) {
        __inochi2d.instance.exports.in_puppet_update(this.#ptr, delta);
    }

    /**
        Draws the puppet.
    */
    draw(delta) {
        __inochi2d.instance.exports.in_puppet_draw(this.#ptr, delta);
    }
}

class InTexture {
    #ptr;

    /**
        Constructs a texture from a pointer.
    */
    constructor(ptr) {
        this.#ptr = ptr;
    }

    /**
        The renderer ID of the texture.
    */
    get id() { return __inochi2d.instance.exports.in_resource_get_id(this.#ptr); }
    set id(value) { __inochi2d.instance.exports.in_resource_set_id(this.#ptr, value); }

    /**
        Width of the texture, in pixels.
    */
    get width() { return __inochi2d.instance.exports.in_texture_get_width(this.#ptr); }

    /**
        Height of the texture, in pixels.
    */
    get height() { return __inochi2d.instance.exports.in_texture_get_height(this.#ptr); }

    /**
        Channel count of the texture.
    */
    get channels() { return __inochi2d.instance.exports.in_texture_get_channels(this.#ptr); }

    /**
        Gets the image data of the texture.
    */
    get imageData() {
        let data = new Uint8ClampedArray(
            __inochi2d.instance.exports.memory.buffer, 
            __inochi2d.instance.exports.in_texture_get_pixels(this.#ptr), 
            __inochi2d.instance.exports.in_resource_get_length(this.#ptr)
        );
        return new ImageData(data, this.width, this.height);
    }

    /**
        Gets the image data of the texture.
    */
    get bytes() {
        return new Uint8Array(
            __inochi2d.instance.exports.memory.buffer, 
            __inochi2d.instance.exports.in_texture_get_pixels(this.#ptr), 
            __inochi2d.instance.exports.in_resource_get_length(this.#ptr)
        );
    }

    /**
        Flips the texture vertically.
    */
    flipVertically() {
        __inochi2d.instance.exports.in_texture_flip_vertically(this.#ptr);
    }

    /**
        Pre-multiplies the texture.
    */
    premultiply() {
        __inochi2d.instance.exports.in_texture_premultiply(this.#ptr);
    }

    /**
        Un pre-multiplies the texture.
    */
    unpremultiply() {
        __inochi2d.instance.exports.in_texture_unpremultiply(this.#ptr);
    }

    /**
        Pads the texture with a transparent border.
    */
    pad(thickness) {
        __inochi2d.instance.exports.in_texture_pad(this.#ptr, thickness);
    }
}

class InDrawList {
    #ptr;

    /**
        Constructs a draw list from a pointer.
    */
    constructor(ptr) {
        this.#ptr = ptr;
        __inochi2d.instance.exports.in_drawlist_set_use_base_vertex(ptr, false);
    }

    /**
        DataView of the vertex data.
    */
    get vertexData() {
        let rptr = __inochi2d.instance.exports.in_drawlist_get_vertex_data(this.#ptr, __inochi2d.scratchpad);
        let size = sp_get_uint32();
        return new DataView(__inochi2d.instance.exports.memory.buffer, rptr, size);
    }

    /**
        DataView of the index data.
    */
    get indexData() {
        let rptr = __inochi2d.instance.exports.in_drawlist_get_index_data(this.#ptr, __inochi2d.scratchpad);
        let count = sp_get_uint32();
        return new DataView(__inochi2d.instance.exports.memory.buffer, rptr, count*4);
    }

    /**
        The queued drawing commands.
    */
    get commands() {
        let rptr = __inochi2d.instance.exports.in_drawlist_get_commands(this.#ptr, __inochi2d.scratchpad);
        let count = sp_get_uint32();

        return {
            *[Symbol.iterator]() {
                for(let i = 0; i < count; i++) {
                    yield read_drawcmd(rptr+(i*IN_DRAWCMD_SIZE));
                }
            }
        }
    }

    /**
        The allocated meshes.
    */
    get allocations() {
        let rptr = __inochi2d.instance.exports.in_drawlist_get_allocations(this.#ptr, __inochi2d.scratchpad);
        let count = sp_get_uint32();

        return {
            *[Symbol.iterator]() {
                for(let i = 0; i < count; i++) {
                    yield read_drawalloc(rptr+(i*IN_DRAWALLOC_SIZE));
                }
            }
        }
    }
}