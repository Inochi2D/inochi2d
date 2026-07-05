

//
//			TYPES
//
export type ptr_t = number;

export type io_sink = {
    error(msg: ptr_t, file: ptr_t, line: number): void; warning(msg: ptr_t, file: ptr_t, line: number) : void;
    info(msg: ptr_t, file: ptr_t, line: number) : void;
}

/**
        Base class of objects.
*/
export abstract class NuObject implements Disposable {
    private ptr_: ptr_t = 0;

    /**
            The underlying pointer.
    */
    get ptr(): ptr_t { return this.ptr_; }

    // Destructor
    [Symbol.dispose]() { __classmap.unregister(this.ptr_); }

    /**
            Constructs a new object.
    */
    constructor(ptr: ptr_t) {
        this.ptr_ = ptr;
        if (ptr != 0)
            __classmap.register(this, this.ptr_);
    }
}

/**
        Base class of reference counted objects.
*/
export abstract class NuRefCounted extends NuObject {

    /**
            Retains a reference to this object.
    */
    retain() { in_retain(this.ptr); }

    /**
            Releases a reference from this object.
    */
    release() {
        if (in_release(this.ptr) == 0)
            this[Symbol.dispose]();
    }
}

//
//			API
//

/**
    Initializes Inochi2D with an optional module path.

    If none are selected, it is assumed that the inochi2d wasm
    module is placed next to the wrapper JS file.
*/
export async function in_init(url: string = "inochi2d.wasm") {
    if (__inochi2d)
        throw new Error("Inochi2D is already initialized!");

    try {
        let result = await WebAssembly.instantiateStreaming(fetch(url), __wasi);
        (result.instance.exports.in_init as unknown as () => void)();
        __inochi2d = {
            module : result.module,
            instance : result.instance,
            exports : result.instance.exports as wasm_exports,
            scratchpad : {size : 0, ptr : scrptr(128)}
        };
    } catch (error) {
        throw error;
    }
}

/**
        Allocates memory in the WebAssembly heap.

        @param {number} bytes - How many bytes to allocate
        @returns {ptr_t} A pointer to the new memory allocation.
*/
export function nu_malloc(bytes: number): ptr_t { return __inochi2d.exports.nu_malloc(bytes); }

/**
        Reallocates memory in the WebAssembly heap.

        @param {ptr_t} ptr - Memory pointer to reallocate.
        @param {number} bytes - How many bytes to allocate
        @returns {ptr_t} A pointer to the new memory allocation.
*/
export function nu_realloc(ptr: ptr_t, bytes: number): ptr_t { return __inochi2d.exports.nu_realloc(ptr, bytes); }

/**
        Frees the memory at the given pointer in the WebAssembly
        heap.

        @param {ptr_t} ptr - Memory pointer to free.
*/
export function nu_free(ptr: ptr_t): void { __inochi2d.exports.nu_free(ptr); }

/**
        Retains a reference to a reference counted
        Inochi2D type.
*/
export function in_retain(ptr: ptr_t): ptr_t { return __inochi2d.exports.in_retain(ptr); }

/**
        Releases a reference from a reference counted
        Inochi2D type.
*/
export function in_release(ptr: ptr_t): ptr_t { return __inochi2d.exports.in_release(ptr); }

//
//			PUPPET
//

/**
        Loads a puppet from memory.
*/
export function in_puppet_load_from_memory<T extends ArrayBufferLike>(data: T): ptr_t {
    let dptr = nu_malloc(data.byteLength);
    stbuf(data, dptr);
    return __inochi2d.exports.in_puppet_load_from_memory(dptr, data.byteLength, 0);
}

/**
        Frees a puppet.
*/
export function in_puppet_free(ptr: ptr_t): void { __inochi2d.exports.in_puppet_free(ptr); }

/**
        Gets the name of a puppet.
*/
export function in_puppet_get_name(ptr: ptr_t): string { return ldstr(__inochi2d.exports.in_puppet_get_name(ptr)); }

/**
        Gets the author of a puppet.
*/
export function in_puppet_get_author(ptr: ptr_t): string { return ldstr(__inochi2d.exports.in_puppet_get_author(ptr)); }

/**
    Gets whether to calculate physics for the puppet.
*/
export function in_puppet_get_physics_enabled(ptr: ptr_t): boolean {
    return __inochi2d.exports.in_puppet_get_physics_enabled(ptr) as boolean;
}

/**
    Sets whether to calculate physics for the puppet.
*/
export function in_puppet_set_physics_enabled(ptr: ptr_t, value: boolean): void {
    __inochi2d.exports.in_puppet_set_physics_enabled(ptr, value);
}

/**
    Gets the pixel-to-meter unit mapping for the physics system.
*/
export function in_puppet_get_pixels_per_meter(ptr: ptr_t): number {
    return __inochi2d.exports.in_puppet_get_pixels_per_meter(ptr);
}

/**
    Sets the pixel-to-meter unit mapping for the physics system.
*/
export function in_puppet_set_pixels_per_meter(ptr: ptr_t, value: number): void {
    __inochi2d.exports.in_puppet_set_pixels_per_meter(ptr, value);
}

/**
    Gets the gravity constant for the puppet.
*/
export function in_puppet_get_gravity(ptr: ptr_t): number { return __inochi2d.exports.in_puppet_get_gravity(ptr); }

/**
    Sets the gravity constant for the puppet.
*/
export function in_puppet_set_gravity(ptr: ptr_t, value: number): void {
    __inochi2d.exports.in_puppet_set_gravity(ptr, value);
}

/**
    Updates a puppet.
*/
export function in_puppet_update(ptr: ptr_t, delta: number): void { __inochi2d.exports.in_puppet_update(ptr, delta); }

/**
    Draws a puppet.
*/
export function in_puppet_draw(ptr: ptr_t, delta: number): void { __inochi2d.exports.in_puppet_draw(ptr, delta); }

/**
        Resets the drivers of a puppet.
*/
export function in_puppet_reset_drivers(ptr: ptr_t): void { __inochi2d.exports.in_puppet_reset_drivers(ptr); }

/**
        Gets the texture cache of a puppet.
*/
export function in_puppet_get_texture_cache(ptr: ptr_t): ptr_t {
    return __inochi2d.exports.in_puppet_get_texture_cache(ptr);
}

/**
        Gets the parameters of a puppet.
*/
export function in_puppet_get_parameters(ptr: ptr_t): [ ptr: ptr_t, count: number ] {
    let rptr = __inochi2d.exports.in_puppet_get_parameters(ptr, scrptr(4));
    return [ rptr, ldu32(scrptr(4)) ];
}

/**
        Gets the drawlist of a puppet.
*/
export function in_puppet_get_drawlist(ptr: ptr_t): ptr_t { return __inochi2d.exports.in_puppet_get_drawlist(ptr); }

/**
        Gets the root node of a puppet.
*/
export function in_puppet_get_root_node(ptr: ptr_t): ptr_t { return __inochi2d.exports.in_puppet_get_root_node(ptr); }

//
//			NODE
//

/**
        Creates a new node with an optional parent.
*/
export function in_node_new(ptr: ptr_t): ptr_t { return __inochi2d.exports.in_node_new(ptr); }

/**
        Gets the given node's parent puppet.
*/
export function in_node_get_puppet(ptr: ptr_t): ptr_t { return __inochi2d.exports.in_node_get_puppet(ptr); }

/**
        Gets the given node's parent node.
*/
export function in_node_get_parent(ptr: ptr_t): ptr_t { return __inochi2d.exports.in_node_get_parent(ptr); }

/**
        Sets the given node's parent node.
*/
export function in_node_set_parent(ptr: ptr_t, value: ptr_t): void {
    __inochi2d.exports.in_node_set_parent(ptr, value);
}

/**
        Gets a slice of the children of the given node.
*/
export function in_node_get_children(ptr: ptr_t): [ ptr: ptr_t, count: number ] {
    let rptr = __inochi2d.exports.in_node_get_children(ptr, scrptr(4));
    return [ rptr, ldu32(scrptr(4)) ];
}

/**
        Gets the name of the given node.
*/
export function in_node_get_name(ptr: ptr_t): string { return ldstr(__inochi2d.exports.in_node_get_name(ptr)); }

/**
        Gets the name of the given node's type.
*/
export function in_node_get_type(ptr: ptr_t): string { return ldstr(__inochi2d.exports.in_node_get_type(ptr)); }

/**
        Gets the z sorting value for the node.
*/
export function in_node_get_zsort(ptr: ptr_t): number { return __inochi2d.exports.in_node_get_zsort(ptr); }

/**
        Gets the tree depth of the node.
*/
export function in_node_get_tree_depth(ptr: ptr_t): number { return __inochi2d.exports.in_node_get_tree_depth(ptr); }

/**
        Gets whether the node is enabled.
*/
export function in_node_get_enabled(ptr: ptr_t): boolean { return __inochi2d.exports.in_node_get_enabled(ptr); }

/**
        Sets whether the node is enabled.
*/
export function in_node_set_enabled(ptr: ptr_t, value: boolean): void {
    __inochi2d.exports.in_node_set_enabled(ptr, value);
}

/**
        Gets whether the node's transform is locked to the root node.
*/
export function in_node_get_lock_to_root(ptr: ptr_t): boolean {
    return __inochi2d.exports.in_node_get_lock_to_root(ptr);
}

/**
        Sets whether the node's transform is locked to the root node.
*/
export function in_node_set_lock_to_root(ptr: ptr_t, value: boolean): void {
    __inochi2d.exports.in_node_set_lock_to_root(ptr, value);
}

/**
        Gets whether the node has the given property.
*/
export function in_node_has_property(ptr: ptr_t, key: string): boolean {
    return __inochi2d.exports.in_node_has_property(ptr, ststr(key));
}

/**
        Gets the given property's current value.
*/
export function in_node_get_property(ptr: ptr_t, key: string): number {
    return __inochi2d.exports.in_node_get_property(ptr, ststr(key));
}

/**
        Gets the given property's default value.
*/
export function in_node_get_property_default(ptr: ptr_t, key: string): number {
    return __inochi2d.exports.in_node_get_property_default(ptr, ststr(key));
}

/**
        Sets the given property's value.
*/
export function in_node_set_property(ptr: ptr_t, key: string, value: number): void {
    __inochi2d.exports.in_node_set_property(ptr, ststr(key), value);
}

/**
        Gets a slice of the mesh effects.
*/
export function in_node_part_get_mesh_effects(ptr: ptr_t): [ ptr: ptr_t, count: number ] {
    let rptr = __inochi2d.exports.in_node_part_get_mesh_effects(ptr, scrptr(4));
    return [ rptr, ldu32(scrptr(4)) ];
}

//
//			PARAMETERS
//

/**
        Gets the name of a given parameter.
*/
export function in_parameter_get_name(ptr: ptr_t): string {
    return ldstr(__inochi2d.exports.in_parameter_get_name(ptr));
}

/**
        Gets whether the given parameter is active.
*/
export function in_parameter_get_active(ptr: ptr_t): boolean { return __inochi2d.exports.in_parameter_get_active(ptr); }

export function in_parameter_get_dimensions(ptr: ptr_t): number {
    return __inochi2d.exports.in_parameter_get_dimensions(ptr);
}

export function in_parameter_get_lower_bounds(ptr: ptr_t): number[] {
    return ldf32arr(__inochi2d.exports.in_parameter_get_lower_bounds(ptr), in_parameter_get_dimensions(ptr));
}

export function in_parameter_get_upper_bounds(ptr: ptr_t): number[] {
    return ldf32arr(__inochi2d.exports.in_parameter_get_upper_bounds(ptr), in_parameter_get_dimensions(ptr));
}

export function in_parameter_get_value(ptr: ptr_t): number[] {
    return ldf32arr(__inochi2d.exports.in_parameter_get_value(ptr), in_parameter_get_dimensions(ptr));
}

export function in_parameter_set_value(ptr: ptr_t, values: number[]): void {
    let dims = in_parameter_get_dimensions(ptr);
    let wptr = scrptr(dims * 4);
    for (let i = 0; i < dims; i++) {
        if (i < values.length)
            stf32(wptr + (i * 4), values[i] as number);
        else
            stf32(wptr + (i * 4), 0);
    }

    __inochi2d.exports.in_parameter_set_value(ptr, wptr);
}

//
//			TEXTURE CACHE
//

export function in_texture_cache_get_size(ptr: ptr_t): number {
    return __inochi2d.exports.in_texture_cache_get_size(ptr);
}

export function in_texture_cache_get_texture(ptr: ptr_t, slot: number): ptr_t {
    return __inochi2d.exports.in_texture_cache_get_texture(ptr, slot);
}

export function in_texture_cache_get_textures(ptr: ptr_t): [ ptr: ptr_t, count: number ] {
    let rptr = __inochi2d.exports.in_texture_cache_get_textures(ptr, scrptr(4));
    return [ rptr, ldu32(scrptr(4)) ];
}

export function in_texture_cache_prune(ptr: ptr_t): void { __inochi2d.exports.in_texture_cache_prune(ptr); }

//
//			RESOURCES
//
export function in_resource_get_length(ptr: ptr_t): number { return __inochi2d.exports.in_resource_get_length(ptr); }

export function in_resource_get_id(ptr: ptr_t): ptr_t { return __inochi2d.exports.in_resource_get_id(ptr); }

export function in_resource_set_id(ptr: ptr_t, value: ptr_t): void {
    __inochi2d.exports.in_resource_set_id(ptr, value);
}

//
//			TEXTURES
//
export function in_texture_get_width(ptr: ptr_t): number { return __inochi2d.exports.in_texture_get_width(ptr); }

export function in_texture_get_height(ptr: ptr_t): number { return __inochi2d.exports.in_texture_get_height(ptr); }

export function in_texture_get_channels(ptr: ptr_t): number { return __inochi2d.exports.in_texture_get_channels(ptr); }

export function in_texture_flip_vertically(ptr: ptr_t): void { __inochi2d.exports.in_texture_flip_vertically(ptr); }

export function in_texture_premultiply(ptr: ptr_t): void { __inochi2d.exports.in_texture_premultiply(ptr); }

export function in_texture_unpremultiply(ptr: ptr_t): void { __inochi2d.exports.in_texture_unpremultiply(ptr); }

export function in_texture_pad(ptr: ptr_t, thickness: number): void {
    __inochi2d.exports.in_texture_pad(ptr, thickness);
}

export function in_texture_get_pixels(ptr: ptr_t): ptr_t { return __inochi2d.exports.in_texture_get_pixels(ptr); }

//
//			DRAWLIST
//
export function in_drawlist_get_use_base_vertex(ptr: ptr_t): boolean {
    return __inochi2d.exports.in_drawlist_get_use_base_vertex(ptr);
}

export function in_drawlist_set_use_base_vertex(ptr: ptr_t, value: boolean): void {
    __inochi2d.exports.in_drawlist_set_use_base_vertex(ptr, value);
}

export function in_drawlist_get_commands(ptr: ptr_t) {}

export function in_drawlist_get_vertex_data(ptr: ptr_t) {}

export function in_drawlist_get_index_data(ptr: ptr_t) {}

export function in_drawlist_get_allocations(ptr: ptr_t) {}

//
//			IMPLEMENTATION DETAILS
//
const __wasi = {
    env : {
        STACKTOP : 0,
        STACK_MAX : 65536,
        abortStackOverflow : function(val: any) { throw new Error("stack overfow"); },
        memory : new WebAssembly.Memory({initial : 256}),
        table : new WebAssembly.Table({initial : 0, element : "anyfunc"}),
        memoryBase : 0,
        tableBase : 2147483648
    },
    wasi_snapshot_preview1 : {
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
};

type wasm_exports = {
    memory: WebAssembly.Memory,
    table: WebAssembly.Table,

    // Numem
    nu_malloc(size: number): ptr_t;
    nu_realloc(ptr: ptr_t, size: number) : ptr_t;
    nu_free(mem: ptr_t) : void;
    in_retain(ptr: ptr_t) : ptr_t;
    in_release(ptr: ptr_t) : ptr_t;

    // Puppet
    in_puppet_load_from_memory(data: ptr_t, length: number, io_sink: ptr_t) : ptr_t;
    in_puppet_free(ptr: ptr_t) : void;
    in_puppet_get_name(ptr: ptr_t) : ptr_t;
    in_puppet_get_physics_enabled(ptr: ptr_t) : boolean;
    in_puppet_set_physics_enabled(ptr: ptr_t, value: boolean) : void;
    in_puppet_get_author(ptr: ptr_t) : ptr_t;
    in_puppet_get_pixels_per_meter(ptr: ptr_t) : number;
    in_puppet_set_pixels_per_meter(ptr: ptr_t, value: number) : void;
    in_puppet_get_gravity(ptr: ptr_t) : number;
    in_puppet_set_gravity(ptr: ptr_t, value: number) : void;
    in_puppet_update(ptr: ptr_t, delta: number) : void;
    in_puppet_draw(ptr: ptr_t, delta: number) : void;
    in_puppet_reset_drivers(ptr: ptr_t) : void;
    in_puppet_get_texture_cache(ptr: ptr_t) : ptr_t;
    in_puppet_get_parameters(ptr: ptr_t, count: ptr_t) : ptr_t;
    in_puppet_get_drawlist(ptr: ptr_t) : ptr_t;
    in_puppet_get_root_node(ptr: ptr_t) : ptr_t;

    // Nodes
    in_node_new(ptr: ptr_t) : ptr_t;
    in_node_get_puppet(ptr: ptr_t) : ptr_t;
    in_node_get_parent(ptr: ptr_t) : ptr_t;
    in_node_set_parent(ptr: ptr_t, value: ptr_t) : void;
    in_node_get_children(ptr: ptr_t, count: ptr_t) : ptr_t;
    in_node_get_name(ptr: ptr_t) : ptr_t;
    in_node_get_type(ptr: ptr_t) : ptr_t;
    in_node_get_guid(ptr: ptr_t) : ptr_t; // TODO: change this?
    in_node_get_zsort(ptr: ptr_t) : number;
    in_node_get_tree_depth(ptr: ptr_t) : number;
    in_node_get_enabled(ptr: ptr_t) : boolean;
    in_node_set_enabled(ptr: ptr_t, value: boolean) : void;
    in_node_get_lock_to_root(ptr: ptr_t) : boolean;
    in_node_set_lock_to_root(ptr: ptr_t, value: boolean) : void;
    in_node_has_property(ptr: ptr_t, key: ptr_t) : boolean;
    in_node_get_property(ptr: ptr_t, key: ptr_t) : number;
    in_node_get_property_default(ptr: ptr_t, key: ptr_t) : number;
    in_node_set_property(ptr: ptr_t, key: ptr_t, value: number) : void;
    in_node_part_get_mesh_effects(ptr: ptr_t, count: ptr_t) : ptr_t;

    // Parameters
    in_parameter_get_name(ptr: ptr_t) : ptr_t;
    in_parameter_get_active(ptr: ptr_t) : boolean;
    in_parameter_get_dimensions(ptr: ptr_t) : number;
    in_parameter_get_lower_bounds(ptr: ptr_t) : ptr_t;
    in_parameter_get_upper_bounds(ptr: ptr_t) : ptr_t;
    in_parameter_get_value(ptr: ptr_t) : ptr_t;
    in_parameter_set_value(ptr: ptr_t, values: ptr_t) : void;

    // Texture Cache
    in_texture_cache_get_size(ptr: ptr_t) : number;
    in_texture_cache_get_texture(ptr: ptr_t, slot: number) : ptr_t;
    in_texture_cache_get_textures(ptr: ptr_t, count: ptr_t) : ptr_t;
    in_texture_cache_prune(ptr: ptr_t) : void;

    // Resources
    in_resource_get_length(ptr: ptr_t) : number;
    in_resource_get_id(ptr: ptr_t) : ptr_t;
    in_resource_set_id(ptr: ptr_t, value: ptr_t) : void;

    // Textures
    in_texture_get_width(ptr: ptr_t) : number;
    in_texture_get_height(ptr: ptr_t) : number;
    in_texture_get_channels(ptr: ptr_t) : number;
    in_texture_flip_vertically(ptr: ptr_t) : void;
    in_texture_premultiply(ptr: ptr_t) : void;
    in_texture_unpremultiply(ptr: ptr_t) : void;
    in_texture_pad(ptr: ptr_t, thickness: number) : void;
    in_texture_get_pixels(ptr: ptr_t) : ptr_t;

    // Drawlist
    in_drawlist_get_use_base_vertex(ptr: ptr_t) : boolean;
    in_drawlist_set_use_base_vertex(ptr: ptr_t, value: boolean) : void;
    in_drawlist_get_commands(ptr: ptr_t, count: ptr_t) : ptr_t;
    in_drawlist_get_vertex_data(ptr: ptr_t, bytes: ptr_t) : ptr_t;
    in_drawlist_get_index_data(ptr: ptr_t, bytes: ptr_t) : ptr_t;
    in_drawlist_get_allocations(ptr: ptr_t, count: ptr_t) : ptr_t;
}

let __inochi2d: {
    module: WebAssembly.Module,
    instance: WebAssembly.Instance,
    exports: wasm_exports,
    scratchpad: {size: number, ptr: ptr_t},
};

//
//			WASM TYPE MAPPING
//

// Helper object mapper.
class NuObjectMap {
    private __registry: Map<ptr_t, NuObject> = new Map<ptr_t, NuObject>();
    register(instance: NuObject, ptr: ptr_t) { this.__registry.set(ptr, instance); }
    unregister(ptr: ptr_t): boolean { return this.__registry.delete(ptr); }
    get<T extends NuObject>(ptr: ptr_t|undefined): T|null {
        return (ptr != undefined && ptr != 0) ? this.__registry.get(ptr as ptr_t) as T : null;
    }
}

var __classmap: NuObjectMap = new NuObjectMap();

//
//			MEMORY I/O
//

// Gets or creates a given type.
export function get_or_create<T extends NuObject>(ptr: ptr_t, CT: new (...args: any[]) => T): T|null {
    let lookup = __classmap.get(ptr);
    if (lookup != null)
        return lookup as T;

    return new CT(ptr);
}

// Extracts a series of wrapped objects from pointers.
export function ptrextract<T extends NuObject>(ptr: ptr_t, count: number,
                                               CT: new (...args: any[]) => T): Array<T|null> {
    let data_view: DataView = new DataView(__inochi2d.exports.memory.buffer, ptr, count * 4);
    let result: Array<T|null> = new Array<T|null>();

    for (let i = 0; i < count; i++)
        result.push(get_or_create<T>(data_view.getUint32(i * 4, true), CT));
    return result;
}

// Gets scratchpad pointer for the given amount of bytes.
function scrptr(size: number = 0, offset: number = 0): ptr_t {
    if (offset + size > __inochi2d.scratchpad.size) {
        __inochi2d.scratchpad.size = offset + size;
        return nu_realloc(__inochi2d.scratchpad.ptr, offset + size) + offset;
    }
    return __inochi2d.scratchpad.ptr + offset;
}

function strlen(ptr: ptr_t): number {
    let wasm_view = new DataView(__inochi2d.exports.memory.buffer, ptr);
    for (let i = 0; i < wasm_view.byteLength; i++) {
        if (wasm_view.getUint8(i) == 0)
            return i;
    }
    return -1;
}

function ldi8(ptr: ptr_t): number { return (new DataView(__inochi2d.exports.memory.buffer)).getInt8(ptr); }
function ldu8(ptr: ptr_t): number { return (new DataView(__inochi2d.exports.memory.buffer)).getUint8(ptr); }
function ldi16(ptr: ptr_t): number { return (new DataView(__inochi2d.exports.memory.buffer)).getInt16(ptr, true); }
function ldu16(ptr: ptr_t): number { return (new DataView(__inochi2d.exports.memory.buffer)).getUint16(ptr, true); }
function ldi32(ptr: ptr_t): number { return (new DataView(__inochi2d.exports.memory.buffer)).getInt32(ptr, true); }
function ldu32(ptr: ptr_t): number { return (new DataView(__inochi2d.exports.memory.buffer)).getUint32(ptr, true); }
function ldf32(ptr: ptr_t): number { return (new DataView(__inochi2d.exports.memory.buffer)).getFloat32(ptr, true); }
function ldbuf<T extends ArrayBufferLike>(ptr: ptr_t, length: number, buf: new (...args: any[]) => T): T {
    return (new buf(__inochi2d.exports.memory.buffer, ptr, length));
}

function ldf32arr(ptr: ptr_t, count: number): number[] {
    let wasm_view = new DataView(__inochi2d.exports.memory.buffer, ptr);
    let result: number[] = [];
    for (let i = 0; i < count; i++)
        result.push(wasm_view.getFloat32(i * 4, true));
    return result;
}

function ldstr(ptr: ptr_t): string {
    if (ptr == 0)
        return "";

    const decoder = new TextDecoder('utf-8');
    return decoder.decode(new DataView(__inochi2d.exports.memory.buffer, ptr, strlen(ptr)));
}

function sti8(ptr: ptr_t, value: number): void { (new DataView(__inochi2d.exports.memory.buffer)).setInt8(ptr, value); }
function stu8(ptr: ptr_t, value: number): void {
    (new DataView(__inochi2d.exports.memory.buffer)).setUint8(ptr, value);
}
function sti16(ptr: ptr_t, value: number): void {
    (new DataView(__inochi2d.exports.memory.buffer)).setInt16(ptr, value, true);
}
function stu16(ptr: ptr_t, value: number): void {
    (new DataView(__inochi2d.exports.memory.buffer)).setUint16(ptr, value, true);
}
function sti32(ptr: ptr_t, value: number): void {
    (new DataView(__inochi2d.exports.memory.buffer)).setInt32(ptr, value, true);
}
function stu32(ptr: ptr_t, value: number): void {
    (new DataView(__inochi2d.exports.memory.buffer)).setUint32(ptr, value, true);
}
function stf32(ptr: ptr_t, value: number): void {
    (new DataView(__inochi2d.exports.memory.buffer)).setFloat32(ptr, value, true);
}
function stbuf<T extends ArrayBufferLike>(buffer: T, ptr: ptr_t): void {
    let dst = new DataView(__inochi2d.exports.memory.buffer);
    let src = new DataView(buffer);
    for (let i = 0; i < buffer.byteLength; i++) {
        dst.setUint8(i + ptr, src.getUint8(i));
    }
}

function ststr(value: string, offset: number = 0): ptr_t {
    const encoder = new TextEncoder();
    let buf = encoder.encode(value);
    stbuf(buf.buffer, scrptr(buf.byteLength + 1, offset));
    stu8(buf.byteLength, 0); // null terminator.
    return scrptr(buf.byteLength, offset);
}