module inochi2d.core.nodes.defstack;
import inochi2d.core;
import inochi2d.core.math;
import inochi2d;
import std.exception : enforce;
import nulib.collections.vector;
import numem;

/**
    A deformation
*/
struct Deformation {
    vec2[] vertexOffsets;

    this(vec2[] data) {
        this.update(data);
    }

    void update(vec2[] points) {
        vertexOffsets.length = points.length;
        vertexOffsets[0..points.length] = points[0..$];
    }

    void clear(size_t length) {
        vertexOffsets.length = length;
        vertexOffsets[0..$] = vec2.zero;
    }

    Deformation opUnary(string op : "-")() @trusted nothrow {
        Deformation new_;

            new_.vertexOffsets.length = vertexOffsets.length;
        foreach(i; 0..vertexOffsets.length) {
            new_.vertexOffsets[i] = -vertexOffsets[i];
        }

        return new_;
    }

    Deformation opBinary(string op : "*", T)(T other) @trusted @nogc nothrow {
        return assumeNoThrowNoGC((Deformation self, T other) { 
            static if (is(T == Deformation)) {
                Deformation new_;

                new_.vertexOffsets.length = self.vertexOffsets.length;
                foreach(i; 0..self.vertexOffsets.length) {
                    new_.vertexOffsets[i] = self.vertexOffsets[i] * other.vertexOffsets[i];
                }

                return new_;
            } else static if (is(T == vec2)) {
                Deformation new_;

                new_.vertexOffsets.length = self.vertexOffsets.length;
                foreach(i; 0..self.vertexOffsets.length) {
                    new_.vertexOffsets[i] = self.vertexOffsets[i] * other;
                }

                return new_;
            } else {
                Deformation new_;

                new_.vertexOffsets.length = self.vertexOffsets.length;
                foreach(i; 0..self.vertexOffsets.length) {
                    new_.vertexOffsets[i] = self.vertexOffsets[i] * other;
                }

                return new_;
            }
        }, this, other);
    }

    Deformation opBinaryRight(string op : "*", T)(T other) @trusted nothrow {
        return assumeNoThrowNoGC((Deformation self, T other) { 
            static if (is(T == Deformation)) {
                Deformation new_;

                new_.vertexOffsets.length = self.vertexOffsets.length;
                foreach(i; 0..self.vertexOffsets.length) {
                    new_.vertexOffsets[i] = other.vertexOffsets[i] * self.vertexOffsets[i];
                }

                return new_;
            } else static if (is(T == vec2)) {
                Deformation new_;

                new_.vertexOffsets.length = self.vertexOffsets.length;
                foreach(i; 0..self.vertexOffsets.length) {
                    new_.vertexOffsets[i] = other * self.vertexOffsets[i];
                }

                return new_;
            } else {
                Deformation new_;

                new_.vertexOffsets.length = self.vertexOffsets.length;
                foreach(i; 0..self.vertexOffsets.length) {
                    new_.vertexOffsets[i] = other * self.vertexOffsets[i];
                }

                return new_;
            }
        }, this, other);
    }

    Deformation opBinary(string op : "+", T)(T other) @trusted nothrow {
        return assumeNoThrowNoGC((Deformation self, T other) { 
            static if (is(T == Deformation)) {
                Deformation new_;

                new_.vertexOffsets.length = self.vertexOffsets.length;
                foreach(i; 0..self.vertexOffsets.length) {
                    new_.vertexOffsets[i] = self.vertexOffsets[i] + other.vertexOffsets[i];
                }

                return new_;
            } else static if (is(T == vec2)) {
                Deformation new_;

                new_.vertexOffsets.length = self.vertexOffsets.length;
                foreach(i; 0..self.vertexOffsets.length) {
                    new_.vertexOffsets[i] = self.vertexOffsets[i] + other;
                }

                return new_;
            } else {
                Deformation new_;

                new_.vertexOffsets.length = self.vertexOffsets.length;
                foreach(i; 0..self.vertexOffsets.length) {
                    new_.vertexOffsets[i] = self.vertexOffsets[i] + other;
                }

                return new_;
            }
        }, this, other);
    }

    Deformation opBinary(string op : "-", T)(T other) @trusted nothrow {
        return assumeNoThrowNoGC((Deformation self, T other) { 
            static if (is(T == Deformation)) {
                Deformation new_;

                new_.vertexOffsets.length = self.vertexOffsets.length;
                foreach(i; 0..self.vertexOffsets.length) {
                    new_.vertexOffsets[i] = self.vertexOffsets[i] - other.vertexOffsets[i];
                }

                return new_;
            } else static if (is(T == vec2)) {
                Deformation new_;

                new_.vertexOffsets.length = self.vertexOffsets.length;
                foreach(i; 0..self.vertexOffsets.length) {
                    new_.vertexOffsets[i] = self.vertexOffsets[i] - other;
                }

                return new_;
            } else {
                Deformation new_;

                new_.vertexOffsets.length = self.vertexOffsets.length;
                foreach(i; 0..self.vertexOffsets.length) {
                    new_.vertexOffsets[i] = self.vertexOffsets[i] - other;
                }

                return new_;
            }
        }, this, other);
    }

    void onSerialize(ref JSONValue data) {
        foreach(offset; vertexOffsets) {
            data ~= offset.serialize();
        }
    }

    void onDeserialize(ref JSONValue data) {
        foreach(ref element; data.array) {
            this.vertexOffsets ~= element.deserialize!vec2();
        }
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