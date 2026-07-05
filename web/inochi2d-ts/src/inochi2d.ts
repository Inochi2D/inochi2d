import {
    get_or_create,
    in_drawlist_get_allocations,
    in_drawlist_get_commands,
    in_drawlist_get_index_data,
    in_drawlist_get_use_base_vertex,
    in_drawlist_get_vertex_data,
    in_drawlist_set_use_base_vertex,
    in_init,
    in_node_get_children,
    in_node_get_enabled,
    in_node_get_lock_to_root,
    in_node_get_name,
    in_node_get_parent,
    in_node_get_property,
    in_node_get_property_default,
    in_node_get_puppet,
    in_node_get_tree_depth,
    in_node_get_type,
    in_node_get_zsort,
    in_node_has_property,
    in_node_new,
    in_node_part_get_mesh_effects,
    in_node_set_enabled,
    in_node_set_lock_to_root,
    in_node_set_parent,
    in_node_set_property,
    in_parameter_get_active,
    in_parameter_get_dimensions,
    in_parameter_get_lower_bounds,
    in_parameter_get_name,
    in_parameter_get_upper_bounds,
    in_parameter_get_value,
    in_parameter_set_value,
    in_puppet_draw,
    in_puppet_free,
    in_puppet_get_author,
    in_puppet_get_drawlist,
    in_puppet_get_gravity,
    in_puppet_get_name,
    in_puppet_get_parameters,
    in_puppet_get_physics_enabled,
    in_puppet_get_pixels_per_meter,
    in_puppet_get_root_node,
    in_puppet_get_texture_cache,
    in_puppet_load_from_memory,
    in_puppet_reset_drivers,
    in_puppet_set_gravity,
    in_puppet_set_physics_enabled,
    in_puppet_set_pixels_per_meter,
    in_puppet_update,
    in_resource_get_id,
    in_resource_get_length,
    in_resource_set_id,
    in_texture_cache_get_size,
    in_texture_cache_get_texture,
    in_texture_cache_get_textures,
    in_texture_cache_prune,
    in_texture_flip_vertically,
    in_texture_get_channels,
    in_texture_get_height,
    in_texture_get_pixels,
    in_texture_get_width,
    in_texture_pad,
    in_texture_premultiply,
    in_texture_unpremultiply,
    NuObject,
    NuRefCounted,
    ptr_t,
    ptrextract,
} from "./core";

/**
        An Inochi2D puppet.
*/
class Puppet extends NuObject {
    private parameters_: Parameter[] = [];

    /**
            The name of the puppet.
    */
    public get name(): string { return in_puppet_get_name(this.ptr); }

    /**
            The author of the puppet.
    */
    public get author(): string { return in_puppet_get_author(this.ptr); }

    /**
            Whether physics are enabled for the puppet.
    */
    public get isPhysicsEnabled(): boolean { return in_puppet_get_physics_enabled(this.ptr); }
    public set isPhysicsEnabled(value: boolean) { in_puppet_set_physics_enabled(this.ptr, value); }

    /**
            The pixel-to-meter unit mapping for the physics system.
    */
    public get pixelsPerMeter(): number { return in_puppet_get_pixels_per_meter(this.ptr); }
    public set pixelsPerMeter(value: number) { in_puppet_set_pixels_per_meter(this.ptr, value); }

    /**
            The gravity constant for the puppet.
    */
    public get gravity(): number { return in_puppet_get_gravity(this.ptr); }
    public set gravity(value: number) { in_puppet_set_gravity(this.ptr, value); }

    /**
            The root node of the puppet.
    */
    public get root(): Node|null { return get_or_create<Node>(in_puppet_get_root_node(this.ptr), Node); }

    /**
            The parameters of the puppet.
    */
    public get parameters(): Parameter[] { return this.parameters_; }

    // Destructor
    override[Symbol.dispose]() {
        super[Symbol.dispose]();
        in_puppet_free(this.ptr);
    }

    /**
            Constructs a new puppet.

            @param {ArrayBufferLike} data - The data to create the puppet from.
    */
    constructor(data: ArrayBufferLike) {
        super(in_puppet_load_from_memory(data));
        let params = in_puppet_get_parameters(this.ptr);
        this.parameters_ = ptrextract<Parameter>(params[0], params[1], Parameter) as Parameter[];
    }

    /**
            Updates the puppet.

            @param {number} delta - Time since last frame in seconds and miliseconds.
    */
    public update(delta: number) { in_puppet_update(this.ptr, delta); }

    /**
            Draws the puppet.

            @param {number} delta - Time since last frame in seconds and miliseconds.
    */
    public draw(delta: number) { in_puppet_draw(this.ptr, delta); }

    /**
            Calls the disposer for this puppet, freeing it.
    */
    public free() { this[Symbol.dispose](); }
}

/**
        An Inochi2D Node.
*/
class Node extends NuRefCounted {

    /**
            The puppet that this node belongs to.
    */
    public get puppet(): Puppet|null { return get_or_create<Puppet>(in_node_get_puppet(this.ptr), Puppet); }

    /**
            The parent of this node.
    */
    public get parent(): Node|null { return get_or_create<Node>(in_node_get_parent(this.ptr), Node); }
    public set parent(value: Node|null) { in_node_set_parent(this.ptr, value ? value.ptr : 0); }

    /**
            The depth of nesting of the node.
    */
    public get depth(): number { return in_node_get_tree_depth(this.ptr); }

    /**
            Name of the node.
    */
    public get name(): string { return in_node_get_name(this.ptr); }

    /**
            The type of the node.
    */
    public get type(): string { return in_node_get_type(this.ptr); }

    /**
            The node's z-sorting value.
    */
    public get zsort(): number { return in_node_get_zsort(this.ptr); }

    /**
            Whether the node is enabled.
    */
    public get enabled(): boolean { return in_node_get_enabled(this.ptr); }
    public set enabled(value: boolean) { in_node_set_enabled(this.ptr, value); }

    /**
            Whether the node's transform is locked to the root node
            of the tree.
    */
    public get isLockedToRoot(): boolean { return in_node_get_lock_to_root(this.ptr); }
    public set isLockedToRoot(value: boolean) { in_node_set_lock_to_root(this.ptr, value); }

    /**
            The children of the node.
    */
    public get children(): Array<Node|null> {
        let result = in_node_get_children(this.ptr);
        return ptrextract<Node>(result[0], result[1], Node);
    }

    /**
            Constructs a new node as an optional subnode of
            another.
    */
    constructor(parent: Node|ptr_t|null) {
        if (typeof parent === "object" || parent == null) {
            super(in_node_new(parent ? parent.ptr : 0));
        } else {
            super(parent as ptr_t);
        }
    }

    /**
            Gets whether the give node has a property with a given key.

            @param {string} key - The key to look up.
            @returns {boolean} true if the key was found, false otherwise.
    */
    public hasProperty(key: string): boolean { return in_node_has_property(this.ptr, key); }

    /**
            Gets the current value of a property.

            @param {string} key - The key to look up.
            @returns {number} the value of the given property.
    */
    public getProperty(key: string): number { return in_node_get_property(this.ptr, key); }

    /**
            Gets the default value of a property.

            @param {string} key - The key to look up.
            @returns {number} the default value of the given property.
    */
    public getPropertyDefault(key: string): number { return in_node_get_property_default(this.ptr, key); }

    /**
            Sets the value of a property.

            @param {string} key - The key to look up.
            @param {number} value - The value to set.
    */
    public setProperty(key: string, value: number): void { in_node_set_property(this.ptr, key, value); }
}

/**
        A parameter.
*/
class Parameter extends NuRefCounted {

    /**
            The name of the parameter.
    */
    public get name(): string { return in_parameter_get_name(this.ptr); }

    /**
            Whether the parameter is active.
    */
    public get isActive(): boolean { return in_parameter_get_active(this.ptr); }

    /**
            The dimensionality of the parameter.
    */
    public get dimensions(): number { return in_parameter_get_dimensions(this.ptr); }

    /**
            Lower bounds of this parameter.
    */
    public get lowerBounds(): number[] { return in_parameter_get_lower_bounds(this.ptr); }

    /**
            Upper bounds of this parameter.
    */
    public get upperBounds(): number[] { return in_parameter_get_upper_bounds(this.ptr); }

    /**
            The value of the parameter.
    */
    public get value(): number[] { return in_parameter_get_value(this.ptr); }
    public set value(value: number[]) { in_parameter_set_value(this.ptr, value); }
}

/**
        Base class of resources.
*/
abstract class Resource extends NuRefCounted {

    /**
            Length of the resource in bytes.
    */
    public get byteLength(): number { return in_resource_get_length(this.ptr); }

    /**
            User setable ID.
    */
    public get id(): number { return in_resource_get_id(this.ptr); }
    public set id(value: number) { in_resource_set_id(this.ptr, value); }
}

/**
        A texture resource.
*/
class Texture extends Resource {}

//
//			EXPORTS
//
export default {in_init, Puppet, Node, Parameter, Resource, Texture}