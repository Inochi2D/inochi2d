module inochi2d.fmt.serialize;
import inochi2d.core.math;
import inochi2d.core;
import inmath.util;
public import std.json;
import std.array : appender, Appender;
import std.functional : forward;
import std.range.primitives : put;

/**
    Interface for classes that can be serialized to JSON with custom code
*/
interface ISerializable {

    /**
        Custom serializer function
    */
    void onSerialize(ref JSONValue object);
}

/**
    Interface for classes that can be deserialized to JSON with custom code
*/
interface IDeserializable {

    /**
        Custom deserializer function
    */
    void onDeserialize(ref JSONValue object);
}

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
    return Puppet.deserialize(parseJson(cast(string)data));
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
    Whether type T can be serialized.
*/
enum isSerializable(T) =
    is(T : ISerializable) || 
    is(typeof((ref JSONValue obj) { T a; a.onSerialize(obj); }));

/**
    Whether type T can be deserialized.
*/
enum isDeserializable(T) =
    is(T : IDeserializable) ||  
    is(typeof((ref JSONValue obj) { T a; a.onDeserialize(obj); }));

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
    T tmp;
    data.deserialize(tmp);
    return tmp;
}

void deserialize(T)(ref JSONValue data, ref T destination) {
    import std.traits : 
        isAggregateType, isArray, 
        isAssociativeArray, isStaticArray;
    import std.traits : KeyType, ValueType;
    import std.range : ElementType;
    enum JSONType JType = toJsonType!T;

    static if (is(T == JSONValue)) {
        destination = data;
    } else {

        // Early return for mismatched types.
        if (data.type != JType || data.type == JSONType.null_)
            return;
        
        static if (isDeserializable!T) {
            destination.onDeserialize(data);
        } else static if (isAssociativeArray!T && is(KeyType!T == string)) {
            alias VType = ValueType!T;
            enum JSONType VJType = toJsonType!VType;

            static if (VJType != JSONType.null_) {
                foreach(key, value; data.object) {
                    VType tmp;
                    value.deserialize(tmp);
                    destination[key] = tmp;
                }
            }
        } else static if (is(T : string)) {
            destination = cast(T)data.get!string;
        } else static if (isStaticArray!T) {
            alias VType = ElementType!T;
            enum JSONType VJType = toJsonType!VType;

            static if (VJType != JSONType.null_) {
                foreach(i, value; data.array) {
                    VType tmp;
                    value.deserialize(tmp);
                    destination[i] = tmp;
                }
            }
        } else static if (isArray!T) {
            alias VType = ElementType!T;
            enum JSONType VJType = toJsonType!VType;

            static if (VJType != JSONType.null_) {
                foreach(value; data.array) {
                    VType tmp;
                    value.deserialize(tmp);
                    destination ~= tmp;
                }
            }
        } else {
            destination = data.get!T;
        }
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

            JSONValue obj = JSONValue.emptyObject;
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
                arr ~= serialize(element);
            }
            return arr;
        } else {
            return JSONValue.emptyArray;
        }
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
    
    return data.get!T();
}

/**
    Attempts to get a value from a JSON object by its key and type.
*/
T tryGet(T)(auto ref JSONValue data, string key, T defaultValue = T.init) {
    if (!data.hasKey(key, toJsonType!T))
        return defaultValue;
    
    return data[key].get!T();
}

/**
    Attempts to get a value from a JSON object by its key and type.
*/
void tryGetRef(T)(ref JSONValue object, ref T dst, string key, T defaultValue = T.init) {
    if (!object.hasKey(key, toJsonType!T)) {
        dst = defaultValue;
        return;
    }
    
    object[key].deserialize(dst);
}

/**
    Gets whether the provided JSON object has the specified
    key.
*/
pragma(inline, true)
bool hasKey()(auto ref JSONValue data, string key) {
    if (!data.isObject)
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
bool isObject()(auto ref JSONValue data) {
    return data.type == JSONType.object;
}

/**
    Gets whether the specified object member is an object.
*/
pragma(inline, true)
bool isObject()(auto ref JSONValue data, string key) {
    if (!data.hasKey(key))
        return false;
    
    return data["key"].type == JSONType.object;
}

/**
    Gets whether the provided JSON data is an array.
*/
pragma(inline, true)
bool isArray()(auto ref JSONValue data) {
    return data.type == JSONType.array;
}

/**
    Gets whether the specified object member is an array.
*/
pragma(inline, true)
bool isArray()(auto ref JSONValue data, string key) {
    if (!data.isObject)
        return false;

    if (key !in data)
        return false;
    
    return data["key"].type == JSONType.array;
}
