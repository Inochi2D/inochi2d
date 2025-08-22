module inochi2d.fmt.serde;
import inochi2d.core.math;
import inochi2d.core;
import inmath.util;
import std.traits;

public import std.json : JSONValue, JSONType, parseJSON, toJSON;
public import inochi2d.fmt.serde.deserializers;
public import inochi2d.fmt.serde.serializers;

/**
    Loads JSON data from file
*/
T inLoadJsonData(T)(string file) {
    return inLoadJsonDataFromMemory(readText(file));
}


/**
    Loads JSON data from memory
*/
T inLoadJsonDataFromMemory(T)(string data) {
    JSONValue v = parseJSON(cast(string)data);
    return Puppet.deserialize(v);
}

/**
    Serialize item with compact Inochi2D JSON serializer
*/
string inToJson(ISerializable item) {
    JSONValue obj;
    item.onSerialize(obj);
    return obj.toJSON();
}

/**
    Serialize item with pretty Inochi2D JSON serializer
*/
string inToJsonPretty(ISerializable item) {
    JSONValue obj;
    item.onSerialize(obj);
    return obj.toPrettyString();
}


//
//          JSON HELPERS
//

/**
    Converts the given type to an equivalent json type.
*/
JSONType toJsonType(T)() {
    import std.traits : isAggregateType, isArray, isAssociativeArray;
    
    static if (is(T : string) || is(T : wstring) || is(T : dstring)) {
        return JSONType.string;
    } else static if (is(T : bool)) {
        return JSONType.true_;  
    } else static if (__traits(isIntegral, T)) {
        static if (__traits(isUnsigned, T)) 
            return JSONType.uinteger;
        else
            return JSONType.integer;
    } else static if (__traits(isFloating, T)) {
        return JSONType.float_;
    } else static if (isAggregateType!T) {
        static if (isSerializable!T || isDeserializable!T)
            return JSONType.object;
        else 
            return JSONType.null_;
    } else static if (isAssociativeArray!T && is(KeyType!T == string)) {
        return JSONType.object;
    } else static if (isArray!T) {
        return JSONType.array;
    } else {
        return JSONType.null_;
    }
}

/**
    Helper which deserializes to an internal intermediate value before
    returning it.
*/
pragma(inline, true)
T deserialize(T)(ref JSONValue data) {
    static if (is(T == class))
        T tmp = new T;
    else
        T tmp;
    
    data.deserialize(tmp);
    return tmp;
}

void deserialize(T)(ref JSONValue data, ref T destination) {
    import inochi2d.fmt.serde.deserializers;
    import inochi2d.core.math;

    static if (is(T == JSONValue)) {
        destination = data;
    } else static if (isDeserializable!T) {
        static if (is(typeof((ref JSONValue obj) { T a; a.onDeserialize(obj); })))
            destination.onDeserialize(data);
        else
            onDeserialize!T(destination, data);
    } else static if (is(T : string)) {
        destination = cast(T)data.str;
    } else static if (is(T == bool)) {
        destination = data.boolean;  
    } else static if (__traits(isFloating, T)) {
        destination = cast(T)data.get!float;
    } else static if (__traits(isIntegral, T)) {
        static if (__traits(isUnsigned, T))
            destination = cast(T)data.get!ulong;
        else 
            destination = cast(T)data.get!long;
    } else {
        destination = data.get!T;
    }
}


/**
    Serializes a given type
*/
JSONValue serialize(T)(auto ref T toSerialize) {
    import std.traits : isAggregateType, isAssociativeArray;
    import std.range : ElementType;
    import std.traits : KeyType, ValueType;
    enum JSONType JType = toJsonType!T;

    static if(is(T == JSONValue)) {
        return toSerialize;  
    } else static if(JType == JSONType.null_) {
        return JSONValue.init;
    } else static if (JType == JSONType.object) {
        static if (isAggregateType!T) {

            JSONValue obj;
            toSerialize.onSerialize(obj);
            return obj;
        } else static if (isAssociativeArray!T && is(KeyType!T == string)) {

            enum JSONType VJType = toJsonType!(ValueType!T);
            static if (VJType != JSONType.null_) {
                JSONValue obj = JSONValue.emptyObject;
                foreach(key, ref value; toSerialize) {
                    obj[key] = value.serialize();
                }
                return obj;
            } else {
                return JSONValue.emptyObject;
            }
        } else {

            return JSONValue.emptyObject;
        }
    } else static if (JType == JSONType.array) {

        enum JSONType EJType = toJsonType!(ElementType!T);
        static if (EJType != JSONType.null_) {
            JSONValue arr = JSONValue.emptyArray;
            foreach(ref element; toSerialize) {
                arr.array ~= serialize(element);
            }
            return arr;
        } else {
            return JSONValue.emptyArray;
        }
    } else static if (__traits(isFloating, T)) { 
        return JSONValue(isFinite(toSerialize) ? toSerialize : 0);  
    } else {
        return JSONValue(toSerialize);
    }
}

/**
    Attempts to get a value from a JSON object by its key and type.
*/
T tryGet(T)(auto ref JSONValue data, T defaultValue = T.init) {
    if (data.type != toJsonType!T)
        return defaultValue;
    
    return data.deserialize!T();
}

/**
    Attempts to get a value from a JSON object by its key and type.
*/
T tryGet(T)(auto ref JSONValue data, string key, T defaultValue = T.init) {
    if (!data.hasKey(key, toJsonType!T))
        return defaultValue;
    
    return data[key].deserialize!T();
}

/**
    Attempts to get a value from a JSON object by its key and type.
*/
void tryGetRef(T)(ref JSONValue object, ref T dst, string key) if (__traits(isFloating, T)) {
    if (!object.hasKey(key, toJsonType!T)) {
        dst = 0.0;
        return;
    }
    
    object[key].deserialize!T(dst);
}

/**
    Attempts to get a value from a JSON object by its key and type.
*/
void tryGetRef(T)(ref JSONValue object, ref T dst, string key, T defaultValue = T.init) {
    if (!object.hasKey(key, toJsonType!T)) {
        dst = defaultValue;
        return;
    }
    
    object[key].deserialize!T(dst);
}

/**
    Gets whether the provided JSON object has the specified
    key.
*/
pragma(inline, true)
bool hasKey()(auto ref JSONValue data, string key) {
    if (!data.isJsonObject)
        return false;

    return (key in data) !is null;
}

/**
    Gets whether the provided JSON object has the specified
    key with the specified type.
*/
pragma(inline, true)
bool hasKey()(auto ref JSONValue data, string key, JSONType type) {
    if (!data.hasKey(key))
        return false;

    return data[key].type == type;
}

/**
    Gets whether the provided JSON data is an object.
*/
pragma(inline, true)
bool isJsonObject()(auto ref JSONValue data) {
    return data.type == JSONType.object;
}

/**
    Gets whether the specified object member is an object.
*/
pragma(inline, true)
bool isJsonObject()(auto ref JSONValue data, string key) {
    if (!data.hasKey(key))
        return false;
    
    return data[key].type == JSONType.object;
}

/**
    Gets whether the provided JSON data is an array.
*/
pragma(inline, true)
bool isJsonArray()(auto ref JSONValue data) {
    return data.type == JSONType.array;
}

/**
    Gets whether the specified object member is an array.
*/
pragma(inline, true)
bool isJsonArray()(auto ref JSONValue data, string key) {
    if (!data.isJsonObject)
        return false;

    if (key !in data)
        return false;
    
    return data[key].type == JSONType.array;
}

/**
    Gets whether the provided JSON data is a scalar.
*/
pragma(inline, true)
bool isScalar()(auto ref JSONValue data) {
    return 
        data.type == JSONType.integer ||
        data.type == JSONType.uinteger ||
        data.type == JSONType.float_;
}
