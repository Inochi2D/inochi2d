/**
    Deformation information.

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.math.deform;
import inochi2d.core;
import inochi2d.core.math;
import inochi2d.common;
import inochi2d;
import nulib.collections.vector;
import numem;

/**
    Interface implemented by types which can be deformed.
*/
interface IDeformable {
@nogc:
public:

    /**
        The base position of the deformable's points.
    */
    @property const(vec2)[] basePoints();

    /**
        The points which may be deformed by the deformer.
    */
    @property vec2[] deformPoints();

    /**
        The base matrix of the object before any parameters have been applied.
    */
    @property Basis deformBaseMatrix();

    /**
        World matrix of the deformable object.
    */
    @property Basis deformMatrix();

    /**
        Deforms the IDeformable.

        Params:
            deformed =  The deformation delta.
            absolute =  Whether the deformation is absolute,
                        replacing the original deformation.
    */
    void deform(vec2[] deformed, bool absolute = false);

    /**
        Deforms a single vertex in the IDeformable

        Params:
            offset =    The offset into the point list to deform.
            deform =    The deformation delta.
            absolute =  Whether the deformation is absolute,
                        replacing the original deformation.
    */
    void deform(size_t offset, vec2 deform, bool absolute = false);

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

    this(ref return scope Deformation other) @trusted @nogc nothrow pure {
        this.vertexOffsets = vertexOffsets.nu_dup();
    }

    this(vec2[] data) @trusted @nogc nothrow pure {
        this.update(data);
    }

    void update(vec2[] points) @trusted @nogc nothrow pure {
        vertexOffsets = vertexOffsets.nu_resize(points.length);
        vertexOffsets[0 .. points.length] = points[0 .. $];
    }

    void clear(size_t length) @trusted @nogc nothrow pure {
        vertexOffsets = vertexOffsets.nu_resize(length);
        vertexOffsets[0 .. $] = vec2.zero;
    }

    Deformation opUnary(string op : "-")() @trusted nothrow pure {
        Deformation new_;

        new_.vertexOffsets.length = vertexOffsets.length;
        foreach (i; 0 .. vertexOffsets.length) {
            new_.vertexOffsets[i] = -vertexOffsets[i];
        }

        return new_;
    }

    Deformation opBinary(string op : "*", T)(T other) @trusted @nogc nothrow pure {
        static if (is(T == Deformation)) {
            Deformation new_;

            new_.clear(this.vertexOffsets.length);
            foreach (i; 0 .. this.vertexOffsets.length) {
                new_.vertexOffsets[i] = this.vertexOffsets[i] * other.vertexOffsets[i];
            }

            return new_;
        } else static if (is(T == vec2)) {
            Deformation new_;

            new_.clear(this.vertexOffsets.length);
            foreach (i; 0 .. this.vertexOffsets.length) {
                new_.vertexOffsets[i] = this.vertexOffsets[i] * other;
            }

            return new_;
        } else {
            Deformation new_;

            new_.clear(this.vertexOffsets.length);
            foreach (i; 0 .. this.vertexOffsets.length) {
                new_.vertexOffsets[i] = this.vertexOffsets[i] * other;
            }

            return new_;
        }
    }

    Deformation opBinaryRight(string op : "*", T)(T other) @trusted nothrow pure {
        static if (is(T == mat4)) {
            
            // Optimized matrix multiplication
            Deformation new_;
            new_.vertexOffsets = self.vertexOffsets.nu_dup();
            simd_mul(new_.vertexOffsets, other);
            
            return new_;  
        } static if (is(T == Deformation)) {
            Deformation new_;

            new_.clear(this.vertexOffsets.length);
            foreach (i; 0 .. this.vertexOffsets.length) {
                new_.vertexOffsets[i] = other.vertexOffsets[i] * this.vertexOffsets[i];
            }

            return new_;
        } else static if (is(T == vec2)) {
            Deformation new_;

            new_.clear(this.vertexOffsets.length);
            foreach (i; 0 .. this.vertexOffsets.length) {
                new_.vertexOffsets[i] = other * this.vertexOffsets[i];
            }

            return new_;
        } else {
            Deformation new_;

            new_.clear(this.vertexOffsets.length);
            foreach (i; 0 .. this.vertexOffsets.length) {
                new_.vertexOffsets[i] = other * this.vertexOffsets[i];
            }

            return new_;
        }
    }

    Deformation opBinary(string op : "+", T)(T other) @trusted nothrow pure {
        static if (is(T == Deformation)) {
            Deformation new_;

            new_.clear(this.vertexOffsets.length);
            foreach (i; 0 .. this.vertexOffsets.length) {
                new_.vertexOffsets[i] = this.vertexOffsets[i] + other.vertexOffsets[i];
            }

            return new_;
        } else static if (is(T == vec2)) {
            Deformation new_;

            new_.clear(this.vertexOffsets.length);
            foreach (i; 0 .. this.vertexOffsets.length) {
                new_.vertexOffsets[i] = this.vertexOffsets[i] + other;
            }

            return new_;
        } else {
            Deformation new_;

            new_.clear(this.vertexOffsets.length);
            foreach (i; 0 .. this.vertexOffsets.length) {
                new_.vertexOffsets[i] = this.vertexOffsets[i] + other;
            }

            return new_;
        }
    }

    Deformation opBinary(string op : "-", T)(T other) @trusted nothrow pure {
        static if (is(T == Deformation)) {
            Deformation new_;

            new_.clear(this.vertexOffsets.length);
            foreach (i; 0 .. this.vertexOffsets.length) {
                new_.vertexOffsets[i] = this.vertexOffsets[i] - other.vertexOffsets[i];
            }

            return new_;
        } else static if (is(T == vec2)) {
            Deformation new_;

            new_.clear(this.vertexOffsets.length);
            foreach (i; 0 .. this.vertexOffsets.length) {
                new_.vertexOffsets[i] = this.vertexOffsets[i] - other;
            }

            return new_;
        } else {
            Deformation new_;

            new_.clear(this.vertexOffsets.length);
            foreach (i; 0 .. this.vertexOffsets.length) {
                new_.vertexOffsets[i] = this.vertexOffsets[i] - other;
            }

            return new_;
        }
    }

    void onSerialize(ref DataNode data) @nogc {
        foreach (offset; vertexOffsets) {
            data ~= offset.serialize();
        }
    }

    void onDeserialize(ref DataNode data, ref ModelState state) @nogc {
        if (state.doUpgrade08) {
            
            this.vertexOffsets = nu_malloca!vec2(data.length);
            foreach (i, ref element; data.array) {
                this.vertexOffsets[i / 2] = element.deserialize!vec2(state);
            }
            return;
        }
    }

    void free() @nogc {
        if (vertexOffsets)
            nu_freea(vertexOffsets);
    }
}
