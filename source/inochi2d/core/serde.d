/**
    Inochi2D SerDe Interface

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.serde;
import inochi2d.core.math;
import inochi2d.core;
import numem.core.traits;
import numath;

public import inp.format;




//
//              INTERFACES
//

/**
    Whether type T can be serialized.
*/
enum isSerializable(T) =
    is(T : ISerializable) ||
    is(typeof((ref DataNode obj) { T a; a.onSerialize(obj); }));

/**
    Interface for classes that can be serialized to JSON with custom code
*/
interface ISerializable {

    /**
        Custom serializer function
    */
    void onSerialize(ref DataNode object);
}


/**
    Interface for classes that can be deserialized to JSON with custom code
*/
interface IDeserializable(ST) {

    /**
        Custom deserializer function
    */
    void onDeserialize(ref DataNode object, ref ST state) @nogc;
}

/**
    Whether type T can be deserialized.
*/
enum isDeserializable(T, ST) =
    is(T : IDeserializable!ST) ||
    is(typeof((ref DataNode obj, ref ST state) { T a; a.onDeserialize(obj, state); })) ||
    is(typeof((ref DataNode obj, ref ST state) { T a; onDeserialize(a, obj, state); }));




//
//              IMPLEMENTATION
//

/**
    Helper which deserializes to an internal intermediate value before
    returning it.
*/
pragma(inline, true)
T deserialize(T, ST)(ref DataNode data, ref ST state) {
    import numem : nogc_new;

    static if (is(T == class))
        T tmp = nogc_new!T;
    else
        T tmp;

    data.deserialize(tmp, state);
    return tmp;
}

pragma(inline, true)
void deserialize(T, ST)(ref DataNode data, ref T destination, ref ST state) @nogc {
    import inochi2d.core.math;
    import nulib.collections : MapImpl, VectorImpl;
    import nulib.string;
    import numem;

    static if (is(T == DataNode)) {
        destination = data;
    } else static if (isDeserializable!(T, ST)) {
        static if (is(T == class) && is(typeof((ref T a) { a = new T; }))) {
            if (!destination)
                destination = nogc_new!T;
        }

        static if (is(typeof((ref DataNode obj) { T a; a.onDeserialize(obj); })))
            destination.onDeserialize(data);
        else static if (is(typeof((ref DataNode obj, ref ST state) { T a; a.onDeserialize(obj, state); })))
            destination.onDeserialize(data, state);
        else static if (is(typeof((ref DataNode obj, ref ST state) { T a; a.deserialize(obj, state); })))
            destination.deserialize(data, state);
        else static assert(0, "Can't deserialize "~T.stringof);

    } else static if (is(T : string) || is(T : nstring)) {
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
    } else static if (__traits(isStaticArray, T)) {
        if (!data.isArray)
            return;

        foreach (i, ref value; data.array) {
            if (i >= T.length)
                break;

            destination[i] = value.deserialize!(ElementType!T, ST)(state);
        }
    } else static if (is(T == VectorImpl!(VT, Args), VT, Args...)) {
        if (!data.isArray)
            return;

        destination.resize(data.length);
        foreach (i, ref value; data.array) {
            destination[i] = value.deserialize!(VT, ST)(state);
        }
    } else static if (is(T == U[], U)) {
        if (!data.isArray)
            return;

        destination = destination.nu_resize(data.length);
        foreach (i, ref value; data.array) {
            destination[i] = value.deserialize!(U, ST)(state);
        }
    } else static if (is(T == MapImpl!(string, VT, Args), VT, Args...)) {
        if (!data.isObject)
            return;

        foreach (key, ref value; data.object) {
            destination[key] = value.deserialize!(VT, ST)(state);
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
T tryGet(T, ST)(auto ref DataNode data, ref ST state, T defaultValue = T.init) {
    static if (__traits(isScalar, T)) {
        static if (__traits(isFloating, T))
            defaultValue = 0.0;

        return data.isNumber ? data.tryCoerce!T : defaultValue;
    }
    if (data.type != dataNodeTypeOf!T)
        return defaultValue;

    return data.deserialize!T(state);
}

/**
    Attempts to get a value from a JSON object by its key and type.
*/
T tryGet(T, ST)(ref DataNode object, ref ST state, string key, T defaultValue = T.init) {
    if (key !in object)
        return defaultValue;

    return object[key].deserialize!(T, ST)(state);
}

/**
    Attempts to get a value from a JSON object by its key and type.
*/
void tryGetRef(T, ST)(ref DataNode object, ref ST state, ref T dst, string key) if (__traits(isFloating, T)) {
    if (key !in object) {
        dst = 0.0;
        return;
    }

    object[key].deserialize!T(dst, state);
}

/**
    Attempts to get a value from a JSON object by its key and type.
*/
void tryGetRef(T, ST)(ref DataNode object, ref ST state, ref T dst, string key, T defaultValue = T.init) {
    if (key !in object) {
        dst = __rvalue(defaultValue);
        return;
    }

    object[key].deserialize!(T, ST)(dst, state);
}