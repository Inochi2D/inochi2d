module inochi2d.core.nodes.defstack;
import inochi2d.core;
import inochi2d.math;
import inochi2d;
import std.exception : enforce;
import numem.all;

/**
    A deformation
*/
struct Deformation {
    vector!vec2 vertexOffsets;

    ~this() @trusted @nogc nothrow {
        nogc_delete(vertexOffsets);
    }

    this(ref Deformation rhs) @trusted @nogc nothrow {
        this.vertexOffsets = vector!vec2(rhs.vertexOffsets);
    }

    this(ref return scope Deformation rhs) @trusted @nogc nothrow {
        this.vertexOffsets = vector!vec2(rhs.vertexOffsets);
    }

    this(vec2[] data) {
        this.update(data);
    }

    this(vector!vec2 data) {
        this.vertexOffsets = vector!vec2(data);
    }

    void update(vec2[] points) {
        vertexOffsets.resize(points.length);
        vertexOffsets.data[0..points.length] = points[0..$];
    }

    void clear(size_t length) {
        import core.stdc.string : memset;
        vertexOffsets.resize(length);
        memset(vertexOffsets.data, 0, vertexOffsets.size()*vertexOffsets.valueType.sizeof);
    }

    Deformation opUnary(string op : "-")() @safe @nogc nothrow {
        Deformation new_;

        new_.vertexOffsets.size() = vertexOffsets.size();
        foreach(i; 0..vertexOffsets.size()) {
            new_.vertexOffsets[i] = -vertexOffsets[i];
        }

        return new_;
    }

    Deformation opBinary(string op : "*", T)(T other) @safe @nogc nothrow {
        static if (is(T == Deformation)) {
            Deformation new_;

            new_.vertexOffsets.resize(vertexOffsets.size());

            foreach(i; 0..vertexOffsets.size()) {
                new_.vertexOffsets[i] = vertexOffsets[i] * other.vertexOffsets[i];
            }

            return new_;
        } else static if (is(T == vec2)) {
            Deformation new_;

            new_.vertexOffsets.resize(vertexOffsets.size());

            foreach(i; 0..vertexOffsets.size()) {
                new_.vertexOffsets[i] = vec2(vertexOffsets[i].x * other.x, vertexOffsets[i].y * other.y);
            }

            return new_;
        } else {
            Deformation new_;

            new_.vertexOffsets.resize(vertexOffsets.size());

            foreach(i; 0..vertexOffsets.size()) {
                new_.vertexOffsets[i] = vertexOffsets[i] * other;
            }

            return new_;
        }
    }

    Deformation opBinaryRight(string op : "*", T)(T other) @safe @nogc nothrow {
        static if (is(T == Deformation)) {
            Deformation new_;

            new_.vertexOffsets.resize(vertexOffsets.size());

            foreach(i; 0..vertexOffsets.size()) {
                new_.vertexOffsets[i] = other.vertexOffsets[i] * vertexOffsets[i];
            }

            return new_;
        } else static if (is(T == vec2)) {
            Deformation new_;

            new_.vertexOffsets.resize(vertexOffsets.size());

            foreach(i; 0..vertexOffsets.size()) {
                new_.vertexOffsets[i] = vec2(other.x * vertexOffsets[i].x, other.y * vertexOffsets[i].y);
            }

            return new_;
        } else {
            Deformation new_;

            new_.vertexOffsets.resize(vertexOffsets.size());

            foreach(i; 0..vertexOffsets.size()) {
                new_.vertexOffsets[i] = other * vertexOffsets[i];
            }

            return new_;
        }
    }

    Deformation opBinary(string op : "+", T)(T other) @safe @nogc nothrow {
        static if (is(T == Deformation)) {
            Deformation new_;

            new_.vertexOffsets.resize(vertexOffsets.size());

            foreach(i; 0..vertexOffsets.size()) {
                new_.vertexOffsets[i] = vertexOffsets[i] + other.vertexOffsets[i];
            }

            return new_;
        } else static if (is(T == vec2)) {
            Deformation new_;

            new_.vertexOffsets.resize(vertexOffsets.size());

            foreach(i; 0..vertexOffsets.size()) {
                new_.vertexOffsets[i] = vec2(vertexOffsets[i].x + other.x, vertexOffsets[i].y + other.y);
            }

            return new_;
        } else {
            Deformation new_;

            new_.vertexOffsets.resize(vertexOffsets.size());

            foreach(i; 0..vertexOffsets.size()) {
                new_.vertexOffsets[i] = vertexOffsets[i] + other;
            }

            return new_;
        }
    }

    Deformation opBinary(string op : "-", T)(T other) @safe @nogc nothrow {
        static if (is(T == Deformation)) {
            Deformation new_;

            new_.vertexOffsets.resize(vertexOffsets.size());

            foreach(i; 0..vertexOffsets.size()) {
                new_.vertexOffsets[i] = vertexOffsets[i] - other.vertexOffsets[i];
            }

            return new_;
        } else static if (is(T == vec2)) {
            Deformation new_;

            new_.vertexOffsets.resize(vertexOffsets.size());

            foreach(i; 0..vertexOffsets.size()) {
                new_.vertexOffsets[i] = vec2(vertexOffsets[i].x - other.x, vertexOffsets[i].y - other.y);
            }

            return new_;
        } else {
            Deformation new_;

            new_.vertexOffsets.resize(vertexOffsets.size());

            foreach(i; 0..vertexOffsets.size()) {
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
        enforce(this.parent.deformation.length == deformation.vertexOffsets.size(), "Mismatched lengths");
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