module inochi2d.core.nodes.defstack;
import inochi2d.core;
import inochi2d.math;
import inochi2d;
import std.exception : enforce;

/**
    A deformation
*/
struct Deformation {

    /**
        Deformed values
    */
    vec2[] vertexOffsets;
}

/**
    A stack of local deformations to apply to the mesh
*/
struct DeformationStack {
private:
    Drawable parent;

public:
    this(Drawable parent) {
        this.parent = parent;
    }

    /**
        Push deformation on to stack
    */
    void push(ref Deformation deformation) {
        enforce(this.parent.deformation.length == deformation.vertexOffsets.length, "Mismatched lengths");
        foreach(i; 0..this.parent.deformation.length) {
            this.parent.deformation[i] += deformation.vertexOffsets[i];
        }
    }
    
    void preUpdate() {
        foreach(i; 0..this.parent.deformation.length) {
            this.parent.deformation[i] = 0f;
        }
    }

    void update() {
        parent.refreshDeform();
    }
}