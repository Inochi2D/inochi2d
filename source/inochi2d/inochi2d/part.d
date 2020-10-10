/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.inochi2d.part;
import inochi2d.inochi2d;
import inochi2d.render;
import inochi2d.math;
import std.algorithm.mutation : remove;
import std.algorithm.searching : countUntil;

/**
    A puppet part
*/
class Part : DynMesh {
private:
    Puppet puppet;
    Part parent;
    Part[] children;

public:

    /**
        Creates a new puppet part
    */
    this(Puppet puppet, Texture texture, MeshData data, Part parent = null) {
        super(texture, data);
        this.puppet = puppet;
        this.setParent(parent);
    }

    /**
        Set this part's parent
    */
    void setParent(Part parent) {
        if (this.parent !is null) {

            // Try to find ourselves in the parent's child list
            ptrdiff_t i = this.parent.children.countUntil(this);

            // Only try to remove ourselves if we could be found
            if (i >= 0) this.parent.children.remove(i);

            // Reset our parent and transform parent
            this.parent = null;
            this.transform.parent = null;
        }
        
        // We don't need to perform any more steps if we're trying to remove our parent only
        if (parent is null) return;

        // Update parent information
        this.parent = parent;
        this.parent.children ~= this;
        this.transform.parent = this.parent.transform;
    }

    /**
        Draws the part
    */
    void draw() {
        super.draw(puppet.scene.camera.matrix(puppet.scene.viewport.x, puppet.scene.viewport.y));
    }
}