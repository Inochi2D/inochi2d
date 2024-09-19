/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.puppet.puppet;
import inochi2d.puppet.node;
import inochi2d.core.io.obj;

@nogc:

/**
    An Inochi2D Puppet
*/
class Puppet : InObject {
@nogc:
private:
    Node root;

public:

    /**
        Serialize the object
    */
    void serialize(ref InDataContext context) {
        InTreeValue treeRoot = context.getRoot();

        treeRoot["rigging_data"] = InTreeValue.newObject();
        this.serialize(*treeRoot.getNodeRef("rigging_data"), context);
    }
    
    /**
        Serialize the object
    */
    override
    void serialize(ref InTreeValue node, ref InDataContext context) {
        InTreeValue nodes = InTreeValue.newObject();
        root.serialize(nodes, context);
        node["nodes"] = nodes;
    }

    /**
        Deserialize the object
    */
    override
    void deserialize(ref InTreeValue node, ref InDataContext context) { }

    /**
        Finalize the object
    */
    override
    void finalize(ref InTreeValue node, ref InDataContext context) {

    }

    /**
        Puppets cannot be copied.
    */
    override
    InObject copy() { return null; }

}