/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/
module inochi2d.puppet.node;
import inochi2d.core.io;
import numem.all;

@nogc:

/**
    An Inochi2D Node
*/
class Node : InObject {
@nogc:
private:

    // Node tree primitives.
    weak_vector!Node children;
    Node parent;

protected:
    
    /**
        Implement copy of self
    */
    Node selfCopy() {
        return nogc_new!Node;
    }

public:
    
    /**
        Serialize the object
    */
    override
    void serialize(ref InpNode node, ref InpContext context) {
        InpNode* childrenArray = InpNode.createArray();
        foreach(ref child; children) {

            // Serialize child
            InpNode* childNode = InpNode.createObject();
            child.serialize(*childNode, context);
            (*childrenArray) ~= childNode;    
        }

        node["children"] = childrenArray;
    }

    /**
        Deserialize the object
    */
    override
    void deserialize(ref InpNode node) {

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

