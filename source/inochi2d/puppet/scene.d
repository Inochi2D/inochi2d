/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.puppet.scene;
import inochi2d.puppet.puppet;
import inochi2d.core.cqueue;
import numem.all;

@nogc:

/**
    An Inochi2D Scene

    Scenes contains and manages puppets, 
    loading and unloading of puppets needs to happen within a scene.

    Scenes owns the memory of a puppet and removing a puppet from a scene will free
    it and its resources from memory.
*/
class Scene {
@nogc:
private:
    CommandQueue queue;
    vector!Puppet puppets;

public:

    /// Destructor
    ~this() {
        nogc_delete(queue);
        nogc_delete(puppets);
    }

    /// Constructor
    this() {
        queue = nogc_new!CommandQueue();
    }

    /**
        Gets the command queue associated with this scene.
    */
    ref CommandQueue getCommandQueue() {
        return queue;
    }

    /**
        Loads a puppet from the specified source.
    */
    void loadPuppet(Stream from) {
        // TODO: Actually load
    }

    /**
        Unloads the specified puppet
    */
    void unloadPuppet(Puppet puppet) {
        foreach(idx, _lpuppet; puppets) {
            
            // Pointer comparison
            if (_lpuppet is puppet) {
                puppets.remove(idx);
                return;
            }
        }
    }

    /**
        Gets puppets loaded in to this scene.
    */
    Puppet[] getLoadedPuppets() {
        return puppets[0..$];
    }
}

