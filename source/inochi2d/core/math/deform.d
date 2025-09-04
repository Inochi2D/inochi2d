/**
    Deformation information.
*/
module inochi2d.core.math.deform;
import inochi2d.core;
import inochi2d.core.math;
import inochi2d;
import std.exception : enforce;
import nulib.collections.vector;
import numem;

/**
    Interface implemented by types which can be deformed.
*/
interface IDeformable {
public:

    /**
        The points which may be deformed by the deformer.
    */
    @property vec2[] deformPoints();

    /**
        Deforms the IDeformable.

        Params:
            deformed =  The deformation delta.
            absolute =  Whether the deformation is absolute,
                        replacing the original deformation.
    */
    void deform(vec2[] deformed, bool absolute = false);

    /**
        Resets the deformation for the IDeformable.
    */
    void resetDeform();
}

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