/*
    Inochi2D Mask

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.mask;
import inochi2d.core.nodes.drawable;
import inochi2d.core;
import inochi2d.math;
import bindbc.opengl;
import std.exception;
import std.algorithm.mutation : copy;

public import inochi2d.core.meshdata;


package(inochi2d) {

    void inInitMask() {
        inRegisterNodeType!Mask;
    }
}

/**
    Dynamic Mask Part
*/
@TypeId("Mask")
class Mask : Drawable {
private:
    this() { }

    /*
        RENDERING
    */
    void drawSelf() {

    }

protected:

    override
    string typeId() { return "Mask"; }

public:
    /**
        Constructs a new mask
    */
    this(Node parent = null) {
        MeshData empty;
        this(empty, inCreateUID(), parent);
    }

    /**
        Constructs a new mask
    */
    this(MeshData data, Node parent = null) {
        this(data, inCreateUID(), parent);
    }

    /**
        Constructs a new mask
    */
    this(MeshData data, uint uid, Node parent = null) {
        super(data, uid, parent);
    }
    
    override
    void renderMask(bool dodge = false) {

    }

    override
    void rebuffer(ref MeshData data) {
        super.rebuffer(data);
    }

    override
    void drawOne() {
        super.drawOne();
    }

    override
    void drawOneDirect(bool forMasking) {
        this.drawSelf();
    }

    override
    void draw() {
        if (!enabled) return;
        foreach(child; children) {
            child.draw();
        }
    }

}