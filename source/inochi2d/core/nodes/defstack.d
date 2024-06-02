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

    void update(vec2[] points) {
        vertexOffsets = points.dup;
    }

    this(this) pure @safe nothrow {
        vertexOffsets = vertexOffsets.dup;
    }

    Deformation opUnary(string op : "-")() @safe pure nothrow {
        Deformation new_;

        new_.vertexOffsets.length = vertexOffsets.length;
        foreach(i; 0..vertexOffsets.length) {
            new_.vertexOffsets[i] = -vertexOffsets[i];
        }

        return new_;
    }

    Deformation opBinary(string op : "*", T)(T other) @safe pure nothrow {
        static if (is(T == Deformation)) {
            Deformation new_;

            new_.vertexOffsets.length = vertexOffsets.length;

            foreach(i; 0..vertexOffsets.length) {
                new_.vertexOffsets[i] = vertexOffsets[i] * other.vertexOffsets[i];
            }

            return new_;
        } else static if (is(T == vec2)) {
            Deformation new_;

            new_.vertexOffsets.length = vertexOffsets.length;

            foreach(i; 0..vertexOffsets.length) {
                new_.vertexOffsets[i] = vec2(vertexOffsets[i].x * other.x, vertexOffsets[i].y * other.y);
            }

            return new_;
        } else {
            Deformation new_;

            new_.vertexOffsets.length = vertexOffsets.length;

            foreach(i; 0..vertexOffsets.length) {
                new_.vertexOffsets[i] = vertexOffsets[i] * other;
            }

            return new_;
        }
    }

    Deformation opBinaryRight(string op : "*", T)(T other) @safe pure nothrow {
        static if (is(T == Deformation)) {
            Deformation new_;

            new_.vertexOffsets.length = vertexOffsets.length;

            foreach(i; 0..vertexOffsets.length) {
                new_.vertexOffsets[i] = other.vertexOffsets[i] * vertexOffsets[i];
            }

            return new_;
        } else static if (is(T == vec2)) {
            Deformation new_;

            new_.vertexOffsets.length = vertexOffsets.length;

            foreach(i; 0..vertexOffsets.length) {
                new_.vertexOffsets[i] = vec2(other.x * vertexOffsets[i].x, other.y * vertexOffsets[i].y);
            }

            return new_;
        } else {
            Deformation new_;

            new_.vertexOffsets.length = vertexOffsets.length;

            foreach(i; 0..vertexOffsets.length) {
                new_.vertexOffsets[i] = other * vertexOffsets[i];
            }

            return new_;
        }
    }

    Deformation opBinary(string op : "+", T)(T other) @safe pure nothrow {
        static if (is(T == Deformation)) {
            Deformation new_;

            new_.vertexOffsets.length = vertexOffsets.length;

            foreach(i; 0..vertexOffsets.length) {
                new_.vertexOffsets[i] = vertexOffsets[i] + other.vertexOffsets[i];
            }

            return new_;
        } else static if (is(T == vec2)) {
            Deformation new_;

            new_.vertexOffsets.length = vertexOffsets.length;

            foreach(i; 0..vertexOffsets.length) {
                new_.vertexOffsets[i] = vec2(vertexOffsets[i].x + other.x, vertexOffsets[i].y + other.y);
            }

            return new_;
        } else {
            Deformation new_;

            new_.vertexOffsets.length = vertexOffsets.length;

            foreach(i; 0..vertexOffsets.length) {
                new_.vertexOffsets[i] = vertexOffsets[i] + other;
            }

            return new_;
        }
    }

    Deformation opBinary(string op : "-", T)(T other) @safe pure nothrow {
        static if (is(T == Deformation)) {
            Deformation new_;

            new_.vertexOffsets.length = vertexOffsets.length;

            foreach(i; 0..vertexOffsets.length) {
                new_.vertexOffsets[i] = vertexOffsets[i] - other.vertexOffsets[i];
            }

            return new_;
        } else static if (is(T == vec2)) {
            Deformation new_;

            new_.vertexOffsets.length = vertexOffsets.length;

            foreach(i; 0..vertexOffsets.length) {
                new_.vertexOffsets[i] = vec2(vertexOffsets[i].x - other.x, vertexOffsets[i].y - other.y);
            }

            return new_;
        } else {
            Deformation new_;

            new_.vertexOffsets.length = vertexOffsets.length;

            foreach(i; 0..vertexOffsets.length) {
                new_.vertexOffsets[i] = vertexOffsets[i] - other;
            }

            return new_;
        }
    }

    void serialize(S)(ref S serializer) {
        import inochi2d.math.serialization : serialize;
        auto state = serializer.arrayBegin();
            foreach(offset; vertexOffsets) {
                serializer.elemBegin;
                offset.serialize(serializer);
            }
        serializer.arrayEnd(state);
    }

    SerdeException deserializeFromFghj(Fghj data) {
        import inochi2d.math.serialization : deserialize;
        foreach(elem; data.byElement()) {
            vec2 offset;
            offset.deserialize(elem);

            vertexOffsets ~= offset;
        }

        return null;
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
        if (this.parent.deformation.length != deformation.vertexOffsets.length) return;
//        enforce(this.parent.deformation.length == deformation.vertexOffsets.length, "Mismatched lengths");
        foreach(i; 0..this.parent.deformation.length) {
            this.parent.deformation[i] += deformation.vertexOffsets[i];
        }
        this.parent.notifyDeformPushed(deformation);
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