/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.puppet.scene;
import inochi2d.puppet.puppet;
import inochi2d.core.draw;
import inochi2d.core.draw.list : DrawList;
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
    DrawList list;
    vector!Puppet puppets;

public:

    /// Destructor
    ~this() {
        nogc_delete(list);
        nogc_delete(puppets);
    }

    /// Constructor
    this() {
        list = nogc_new!DrawList();
    }

    /**
        Gets the command queue associated with this scene.
    */
    ref DrawList getDrawList() {
        return list;
    }

    /**
        Loads a puppet from the specified source.
    */
    Puppet loadPuppet(Stream from) {
        // TODO: Actually load
        return null;
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
        Gets the amount of loaded puppets.
    */
    size_t getPuppetCount() {
        return puppets.size();
    }

    /**
        Gets puppets loaded in to this scene.
    */
    Puppet[] getLoadedPuppets() {
        return puppets[0..$];
    }
}

