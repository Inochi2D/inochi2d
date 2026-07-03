import { 
	ptr_t,
	NuObject, 
	NuRefCounted,
	get_or_create,
	ptrextract,
	in_puppet_free,
	in_puppet_load_from_memory,
	in_puppet_get_name,
	in_puppet_get_author,
	in_puppet_get_physics_enabled,
	in_puppet_set_physics_enabled,
	in_puppet_get_pixels_per_meter,
	in_puppet_set_pixels_per_meter,
	in_puppet_get_root_node,
	in_puppet_get_gravity,
	in_puppet_set_gravity,
	in_puppet_update,
	in_puppet_draw,
	in_node_new,
	in_node_get_puppet,
	in_node_get_parent,
	in_node_set_parent,
	in_node_get_children,
	in_node_get_name,
	in_node_get_type,
	in_node_get_zsort,
	in_node_get_tree_depth,
	in_node_get_enabled,
	in_node_set_enabled,
	in_node_get_lock_to_root,
	in_node_set_lock_to_root,
	in_node_has_property,
	in_node_get_property,
	in_node_get_property_default,
	in_node_set_property,
	in_node_part_get_mesh_effects
} from "./core";

/**
	An Inochi2D puppet.
*/
class Puppet extends NuObject {

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
		The root node of the model.
	*/
	public get root(): Node | null { return get_or_create<Node>(in_puppet_get_root_node(this.ptr), Node); }

	// Destructor
	override [Symbol.dispose]() {
		super[Symbol.dispose]();
		in_puppet_free(this.ptr);
	}

	/**
		Constructs a new puppet.

		@param {ArrayBufferLike} data - The data to create the puppet from.
	*/
	constructor(data: ArrayBufferLike) {
		super(in_puppet_load_from_memory(data));
	}

	/**
		Updates the puppet.

		@param {number} delta - Time since last frame in seconds and miliseconds.
	*/
	update(delta: number) {
		in_puppet_update(this.ptr, delta);
	}

	/**
		Draws the puppet.

		@param {number} delta - Time since last frame in seconds and miliseconds.
	*/
	draw(delta: number) {
		in_puppet_draw(this.ptr, delta);
	}

	/**
		Calls the disposer for this puppet, freeing it.
	*/
	free() {
		this[Symbol.dispose]();
	}
}

/**
	An Inochi2D Node.
*/
class Node extends NuRefCounted {

	/**
		The puppet that this node belongs to.
	*/
	public get puppet(): Puppet | null { return get_or_create<Puppet>(in_node_get_puppet(this.ptr), Puppet); }

	/**
		The parent of this node.
	*/
	public get parent(): Node | null { return get_or_create<Node>(in_node_get_parent(this.ptr), Node); }
	public set parent(value: Node | null) { in_node_set_parent(this.ptr, value ? value.ptr : 0); }
	
	/**
		The children of this node.
	*/
	public get children(): Array<Node | null> {
		let result = in_node_get_children(this.ptr);
		return ptrextract<Node>(result[0], result[1], Node);
	}

	/**
		Constructs a new node as an optional subnode of
		another.
	*/
	constructor(parent: Node | ptr_t | null) {
		if (typeof parent === "object" || parent == null) {
			super(in_node_new(parent ? parent.ptr : 0));
		} else {
			super(parent as ptr_t);
		}
	}
}