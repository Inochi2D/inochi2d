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

    Deformation opBinary(string op : "*")(float other) {
        Deformation new_;

        new_.vertexOffsets.length = vertexOffsets.length;

        foreach(i; 0..vertexOffsets.length) {
            new_.vertexOffsets[i] = vertexOffsets[i] * other;
        }

        return new_;
    }

    Deformation opBinary(string op : "+")(Deformation other) {
        assert(vertexOffsets.length == other.vertexOffsets.length);

        Deformation new_;
        new_.vertexOffsets.length = vertexOffsets.length;

        foreach(i; 0..vertexOffsets.length) {
            new_.vertexOffsets[i] = vertexOffsets[i] + other.vertexOffsets[i];
        }

        return new_;
    }
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
            this.parent.deformation[i] = vec2(0);
        }
    }

    void update() {
        parent.refreshDeform();
    }
}