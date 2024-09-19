/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/
module inochi2d.puppet.node;
import inochi2d.core.io;
import numem.all;
import numem.core.uuid;
import numem.core.random;

@nogc:

private {
    __gshared Random _inRandom;
}

/**
    An Inochi2D Node
*/
class Node : InObject {
@nogc:
private:
    UUID uuid;

    // LEGACY
    uint id;

    // Node tree primitives.
    weak_vector!Node children;
    Node parent;

protected:
    
    /**
        Implement copy of self
    */
    Node selfCopy() {
        Node theCopy = nogc_new!Node;
        theCopy.uuid = inNewUUID();
        return theCopy;
    }

    Node findChild(UUID uuid) {
        foreach(child; children) {
            if (child.uuid == uuid) return child;
        }
        return null;
    }

public:
    
    // Base constructor
    this() {
        
    }
    
    /**
        Serialize the object
    */
    override
    void serialize(ref InTreeValue node, ref InDataContext context) {
        node["uuid"] = InTreeValue(uuid);

        InTreeValue childrenArray = InTreeValue.newArray();
        foreach(ref child; children) {

            // Serialize child
            InTreeValue childNode = InTreeValue.newObject();
            child.serialize(childNode, context);

            // Add to children
            childrenArray ~= childNode;    
        }

        // Add children to this node
        node["children"] = childrenArray;
    }

    /**
        Deserialize the object
    */
    override
    void deserialize(ref InTreeValue node, ref InDataContext context) {
        
        if (node["id"].isValid()) {
            // Inochi2D 0.8
            this.id = node["id"].get!int;
            this.uuid = context.mapLegacyID(id);
        } else {
            // Inochi2D 0.9
            this.uuid = node["uuid"].get!UUID;
        }

        // Iterate children
        if (node["children"].isValid()) {
            foreach(i; 0..node["children"].getLength()) {

                Node n;

                // Get children
                InTreeValue childTree = node["children"][i];
                n.deserialize(childTree, context);
            }
        }
    }

    /**
        Deserialize the object
    */
    override
    void finalize(ref InTreeValue node, ref InDataContext context) {

        // Iterate children, at least if there is any.
        if (node["children"].isValid()) {
            foreach(i; 0..node["children"].getLength()) {

                // Get children
                InTreeValue childTree = node["children"][i];
                
                // Handle UUID mapping for child nodes
                // Including 0.8 nodes
                UUID childNodeUUID;
                if (childTree["id"].isValid()) {

                    // Inochi2D 0.8
                    childNodeUUID = context.getMappingFor(childTree["id"].get!uint);

                } else {

                    // Inochi2D 0.9
                    childNodeUUID = childTree["uuid"].get!UUID;
                }

                // Finally iterate children.
                if (Node child = this.findChild(childNodeUUID)) {

                    // We've instantiated the child, finalize it.
                    child.finalize(childTree, context);
                }
            }
        }
    }

    /**
        Creates a copy of the object.

        This should be a deep copy.
    */
    override
    InObject copy() {
        Node obj = selfCopy();

        // Copy all children as well
        foreach(ref child; children) {
            obj.children ~= cast(Node)child.copy();
        }

        return obj;
    }

}

/**
    Creates a new UUID
*/
UUID inNewUUID() {
    return UUID.createRandom(_inRandom);
}


/**
    Initializes the nodes subsystem

    Is called automatically by inInit
*/
void inInitNodes() {
    _inRandom = nogc_new!Random();
}