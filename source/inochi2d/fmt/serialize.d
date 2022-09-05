module inochi2d.fmt.serialize;
import inochi2d.core;
import std.json;
public import fghj;
public import inochi2d.math.serialization;

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
    void serialize(S)(ref S serializer);
}

/**
    Interface for classes that can be deserialized to JSON with custom code
*/
interface IDeserializable(T) {

    /**
        Custom deserializer function
    */
    static T deserialize(Fghj data);
}

/**
    Tells serializer to ignore
*/
alias Ignore = serdeIgnore;

/**
    Tells serializer that a key is optional
*/
alias Optional = serdeOptional;

/**
    Sets the name of a key.

    First key is JSON key name, second is human-readable name
*/
alias Name = serdeKeys;

/**
    Loads JSON data from memory
*/
T inLoadJsonData(T)(string file) {
    return inLoadJsonDataFromMemory(readText(file));
}


/**
    Loads JSON data from memory
*/
T inLoadJsonDataFromMemory(T)(string data) {
    return deserialize!T(parseJson(cast(string)data));
}

/**
    Serialize item with compact Inochi2D JSON serializer
*/
string inToJson(T)(T item) {
    auto app = appender!(char[]);
    auto serializer = inCreateSerializer(app);
    serializer.serializeValue(item);
    serializer.flush();
    return cast(string)app.data;
}

/**
    Serialize item with pretty Inochi2D JSON serializer
*/
string inToJsonPretty(T)(T item) {
    auto app = appender!(char[]);
    auto serializer = inCreatePrettySerializer(app);
    serializer.serializeValue(item);
    serializer.flush();
    return cast(string)app.data;
}

alias InochiSerializer = JsonSerializer!("", void delegate(const(char)[]) pure nothrow @safe);

/**
    Creates a pretty-serializer
*/
InochiSerializer inCreateSerializer(Appender!(char[]) app) {
    return InochiSerializer((const(char)[] chars) => put(app, chars));
}


string getString(Fghj data) {
    auto app = appender!(char[]);
    data.toString((const(char)[] chars) => put(app, chars));
    return cast(string)app.data;
}