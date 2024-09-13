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
    override
    void serialize(ref InpNode node, ref InpContext context) {
        
    }

    /**
        Deserialize the object
    */
    override
    void deserialize(ref InpNode node) { }

    /**
        Puppets cannot be copied.
    */
    override
    InObject copy() { return null; }

}