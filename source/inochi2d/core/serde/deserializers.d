/**
    Inochi2D Deserialization Interface

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.serde.deserializers;
import inochi2d.core.serde;
import inochi2d.core.math;
import inochi2d.core;
import numath;

/**
    Interface for classes that can be deserialized to JSON with custom code
*/
interface IDeserializable {

    /**
        Custom deserializer function
    */
    void onDeserialize(ref DataNode object) @nogc;
}

/**
    Whether type T can be deserialized.
*/
enum isDeserializable(T) =
    is(T : IDeserializable) ||
    is(typeof((ref DataNode obj) { T a; a.onDeserialize(obj); })) ||
    is(typeof((ref DataNode obj) { T a; onDeserialize!T(a, obj); }));

/**
    Deserializes a provided vector.

    Params:
        dst =   The destination vector
        value = The JSON to deserialize from
    
    Returns:
        The deserialized vector
*/
void onDeserialize(T)(ref T dst, ref DataNode value) @nogc if (isVector!T) {
    foreach (i, element; value.array) {
        if (i >= T.dimension)
            break;
        dst.vector[i] = element.get!(T.vt);
    }
}

/**
    Array deserializer.
*/
void onDeserialize(T)(ref T dst, ref DataNode object) @nogc if (isArray!T) {
    import std.range : ElementType;

    alias ET = ElementType!T;

    if (object.isJsonArray) {
        static if (isVector!ET) {
            float[] tmp = object.tryGet!(float[])();
            size_t dim = ET.dimension;

            dst.length = tmp.length / dim;
            foreach (i; 0 .. dst.length) {
                size_t s = i * dim;
                size_t e = s + dim;
                dst[i].vector[0 .. dim] = tmp[s .. e];
            }
        } else static if (__traits(isScalar, ET)) {

            static if (__traits(isFloating, ET))
                alias FT = float;
            else static if (is(ET == bool))
                alias FT = bool;
            else static if (__traits(isUnsigned, ET))
                alias FT = size_t;
            else static if (__traits(isIntegral, ET))
                alias FT = ptrdiff_t;

            // Scalar optimisation
            DataNode[] arr = object.arrayNoRef;
            static if (isDynamicArray!T)
                dst = new ET[arr.length];

            foreach (i; 0 .. arr.length) {
                static if (isStaticArray!T)
                    if (i >= dst.length)
                        break;

                dst[i] = cast(ET)arr[i].get!FT();
            }

        } else {
            DataNode[] arr = object.arrayNoRef;
            if (arr.length > 0) {

                static if (isDynamicArray!T)
                    dst.length = arr.length;

                foreach (i, ref DataNode value; arr) {
                    static if (isStaticArray!T)
                        if (i >= dst.length)
                            break;

                    static if (isArray!ET) {
                        value.deserialize(dst[i]);
                    } else static if (isDeserializable!ET) {
                        static if (is(ET == class))
                            dst[i] = new ET;

                        dst[i].onDeserialize(value);
                    }
                }
            }
        }
    }
}
