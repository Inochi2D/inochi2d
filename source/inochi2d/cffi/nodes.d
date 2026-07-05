/**
    C FFI for nodes.

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.cffi.nodes;
import inochi2d.cffi.puppet;
import inochi2d.nodes;
import inochi2d.core;
import inochi2d.cffi;
import nulib.string;
import numath;
import numem;

version (IN_DYNLIB) :
extern (C) export @nogc:

//
//              NODE
//

/**
    Opaque handle for a node.
*/
struct in_node_t;

/**
    Creates a new basic node, optionally parented to the given node.

    Params:
        parent = The parent of the newly created node, or null.
    
    Returns:
        The newly allocated node.
*/
in_node_t* in_node_new(in_node_t* parent) {
    return cast(in_node_t*)nogc_new!Node(cast(Node)parent);
}

/**
    Gets the puppet that the node belongs to.

    Params:
        self = The node to operate on.
    
    Returns:
        The parent puppet or $(D null) if puppet is unrooted.
*/
in_puppet_t* in_node_get_puppet(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return cast(in_puppet_t*)n_self.puppet;
    return null;
}

/**
    Gets the parent node of the given node.

    Params:
        self = The node to operate on.
    
    Returns:
        Pointer to the parent node, or $(D null)
        if the node is the root of its tree.
*/
in_node_t* in_node_get_parent(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return cast(in_node_t*)n_self.parent;
    return null;
}

/**
    Sets the parent of the given node.

    Params:
        self =      The node to operate on.
        parent =    The parent to set, or $(D null).
*/
void in_node_set_parent(in_node_t* self, in_node_t* parent) {
    if (Node n_self = cast(Node)self)
        n_self.parent = cast(Node)parent;
}

/**
    Gets the child nodes of the given node.

    Params:
        self =  The node to operate on.
        count = Where to store the node count.

    Returns:
        A node-owned array of nodes.
*/
in_node_t** in_node_get_children(in_node_t* self, uint* count) {
    if (Node n_self = cast(Node)self) {
        *count = cast(uint)n_self.children.length;
        return cast(in_node_t**)n_self.children.ptr;
    }

    return null;
}

/**
    Gets the name of the node.

    Params:
        self = The node to operate on.

    Returns:
        The name of the node.
*/
const(char)* in_node_get_name(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return n_self.name.ptr;
    
    return null;
}

/**
    Gets the type of the node.

    Params:
        self = The node to operate on.

    Returns:
        The type id of the node.
*/
const(char)* in_node_get_type(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return n_self.typeId.sid.ptr;

    return null;
}

/**
    Gets whether the node is enabled.

    Params:
        self = The node to operate on.

    Returns:
        $(D true) if the node is enabled,
        $(D false) otherwise.
*/
bool in_node_get_enabled(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return n_self.enabled;

    return false;
}

/**
    Sets whether the node is enabled.

    Params:
        self =  The node to operate on.
        value = The value to set.
*/
void in_node_set_enabled(in_node_t* self, bool value) {
    if (Node n_self = cast(Node)self)
        n_self.enabled = value;
}

/**
    Gets whether the node's transform is locked to the root
    node.

    Params:
        self = The node to operate on.

    Returns:
        $(D true) if the transformation of the node is locked
        to the root node, $(D false) otherwise.
*/
bool in_node_get_lock_to_root(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return n_self.lockToRoot;

    return false;
}

/**
    Sets whether the node's transform is locked to the root
    node.

    Params:
        self =  The node to operate on.
        value = The value to set.
*/
void in_node_set_lock_to_root(in_node_t* self, bool value) {
    if (Node n_self = cast(Node)self)
        n_self.lockToRoot = value;
}

/**
    Gets the depth of the node in the node tree.

    Params:
        self =  The node to operate on.
    
    Returns:
        The depth of the node in the tree.
*/
uint in_node_get_tree_depth(in_node_t* self) {
    if (Node n_self = cast(Node)self)
        return n_self.depth;

    return 0;
}

/**
    Gets whether the node has the given property.

    Params:
        self =  The node to operate on.
        key =   Name of the property to query.
    
    Returns:
        $(D true) if the node has the given property,
        $(D false) otherwise.
*/
bool in_node_has_property(in_node_t* self, quark_t key) {
    if (key) {
        if (Node n_self = cast(Node)self)
            return n_self.hasProperty(key);
    }
    return false;
}

/**
    Gets the value of the given property.

    Params:
        self =  The node to operate on.
        key =   Name of the property to query.
    
    Returns:
        The value of the property.
*/
float in_node_get_property(in_node_t* self, quark_t key) {
    if (key) {
        if (Node n_self = cast(Node)self)
            return n_self.getProperty(key);
    }
    return 0;
}

/**
    Gets the default value of the given property.

    Params:
        self =  The node to operate on.
        key =   Name of the property to query.
    
    Returns:
        The default value of the property.
*/
float in_node_get_property_default(in_node_t* self, quark_t key) {
    if (key) {
        if (Node n_self = cast(Node)self)
            return n_self.getPropertyDefault(key);
    }
    return 0;
}

/**
    Sets the value of the given property.

    Params:
        self =  The node to operate on.
        key =   Name of the property to query.
        value = Value to assign the property to.
    
    Returns:
        The default value of the property.
*/
void in_node_set_property(in_node_t* self, quark_t key, float value) {
    if (key) {
        if (Node n_self = cast(Node)self)
            return n_self.setProperty(key, value);
    }
}

//
//              PART & MESH EFFECT
//

/**
    Opaque handle for a mesh effect.
*/
struct in_mesh_effect_t;

/**
    Gets the mesh effects attached to a node.

    Params:
        self =  The node to operate on.
        count = Variablt to store the effect count in.
    
    Returns:
        A Part-owned array of mesh effects.
*/
in_mesh_effect_t** in_node_part_get_mesh_effects(in_node_t* self, uint* count) {
    if (Node n_node = cast(Node)self) {
        if (Part n_self = cast(Part)n_node) {
            *count = cast(uint)n_self.effects.length;
            return cast(in_mesh_effect_t**)n_self.effects.ptr;
        }
    }
    return null;
}