/**
    Inochi2D Serialization and Deserialization.

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.serde;
import inochi2d.core.math;
import inochi2d.core;
import numath;
import numem.core.traits;

public import inochi2d.core.serde.deserializers;
public import inochi2d.core.serde.serializers;
public import inp.format;

/**
    Helper which deserializes to an internal intermediate value before
    returning it.
*/
pragma(inline, true)
T deserialize(T)(ref DataNode data) {
    import numem : nogc_new;

    static if (is(T == class))
        T tmp = nogc_new!T;
    else
        T tmp;

    data.deserialize(tmp);
    return tmp;
}

pragma(inline, true)
void deserialize(T)(ref DataNode data, ref T destination) @nogc {
    import inochi2d.core.serde.deserializers;
    import inochi2d.core.math;
    import nulib.collections : MapImpl, VectorImpl;
    import numem;

    static if (is(T == DataNode)) {
        destination = data;
    } else static if (isDeserializable!T) {
        static if (is(T == class) && is(typeof((ref T a) { a = new T; }))) {
            if (!destination)
                destination = nogc_new!T;
        }

        static if (is(typeof((ref DataNode obj) { T a; a.onDeserialize(obj); })))
            destination.onDeserialize(data);
        else
            destination.deserialize(data);
    } else static if (is(T : string)) {
        if (!data.isNull)
            destination = cast(T)data.text;
    } else static if (is(T == bool)) {
        destination = data.boolean;
    } else static if (__traits(isFloating, T)) {
        destination = cast(T)data.tryCoerce!float;
    } else static if (__traits(isIntegral, T)) {
        static if (__traits(isUnsigned, T))
            destination = cast(T)data.tryCoerce!ulong;
        else
            destination = cast(T)data.tryCoerce!long;
    } else static if (is(T == VectorImpl!(VT, Args), VT, Args...)) {
        if (!data.isArray)
            return;

        destination.resize(data.length);
        foreach (i, ref value; data.array) {
            destination[i] = value.deserialize!VT();
        }
    } else static if (is(T == U[], U)) {
        if (!data.isArray)
            return;

        destination = destination.nu_resize(data.length);
        foreach (i, ref value; data.array) {
            destination[i] = value.deserialize!U();
        }
    } else static if (is(T == MapImpl!(string, VT, Args), VT, Args...)) {
        if (!data.isObject)
            return;

        foreach (key, ref value; data.object) {
            destination[key] = value.deserialize!VT();
        }
    } else {
        destination = data.tryCoerce!T;
    }
}

/**
    Serializes a given type
*/
DataNode serialize(T)(auto ref T toSerialize) @nogc {
    import std.traits : isAggregateType, isAssociativeArray;
    import std.range : ElementType;
    import std.traits : KeyType, ValueType;
    import nulib.collections;

    enum VType = dataNodeTypeOf!T;

    static if (is(T == DataNode)) {
        return toSerialize;
    } else static if (VType == DataNodeType.undefined) {
        return DataNode.init;
    } else static if (VType == DataNodeType.object_) {
        static if (is(T == MapImpl!(string, VT, Args), VT, Args...)) {

            enum DataNodeType VDType = dataNodeTypeOf!VT;
            static if (VDType != DataNodeType.undefined) {
                DataNode obj = DataNode.createObject();
                foreach (kv; toSerialize.byKeyValue) {
                    obj[kv.key] = kv.value.serialize();
                }
                return obj;
            } else {
                return DataNode.createObject();
            }

        } else static if (is(T == VectorImpl!(VT, Args), VT, Args...)) {

            enum EVType = dataNodeTypeOf!VT;
            static if (EVType != DataNodeType.undefined) {
                DataNode arr = DataNode.createArray();
                foreach (ref element; toSerialize) {
                    arr.array ~= serialize(element);
                }
                return arr;
            } else {
                return DataNode.createArray();
            }
        } else static if (isAggregateType!T) {

            DataNode obj;
            toSerialize.onSerialize(obj);
            return obj;
        } else {
            return DataNode.createObject();
        }
    } else static if (VType == DataNodeType.array_) {

        enum EVType = dataNodeTypeOf!(ElementType!T);
        static if (EVType != DataNodeType.undefined) {
            DataNode arr = DataNode.createArray();
            foreach (ref element; toSerialize) {
                arr.array ~= serialize(element);
            }
            return arr;
        } else {
            return DataNode.createArray();
        }
    } else static if (__traits(isFloating, T)) {
        return DataNode(isFinite(toSerialize) ? toSerialize : 0);
    } else {
        return DataNode(toSerialize);
    }
}

/**
    Attempts to get a value from a JSON object by its key and type.
*/
T tryGet(T)(auto ref DataNode data, T defaultValue = T.init) {
    static if (__traits(isScalar, T)) {
        static if (__traits(isFloating, T))
            defaultValue = 0.0;

        return data.isNumber ? data.tryCoerce!T : defaultValue;
    }
    if (data.type != dataNodeTypeOf!T)
        return defaultValue;

    return data.deserialize!T();
}

/**
    Attempts to get a value from a JSON object by its key and type.
*/
T tryGet(T)(ref DataNode object, string key, T defaultValue = T.init) {
    if (key !in object)
        return defaultValue;

    return object[key].deserialize!T();
}

/**
    Attempts to get a value from a JSON object by its key and type.
*/
void tryGetRef(T)(ref DataNode object, ref T dst, string key) if (__traits(isFloating, T)) {
    if (key !in object) {
        dst = 0.0;
        return;
    }

    object[key].deserialize!T(dst);
}

/**
    Attempts to get a value from a JSON object by its key and type.
*/
void tryGetRef(T)(ref DataNode object, ref T dst, string key, T defaultValue = T.init) {
    if (key !in object) {
        dst = __rvalue(defaultValue);
        return;
    }

    object[key].deserialize!T(dst);
}
