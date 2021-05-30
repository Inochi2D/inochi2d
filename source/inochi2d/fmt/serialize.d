module inochi2d.fmt.serialize;
import inochi2d.core;
import std.json;
public import asdf;
public import inochi2d.math.serialization;

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
    static T deserialize(Asdf data);
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
    Test
*/
string inToJson(T)(T item) {
    return serializeToJsonPretty(item);
}

/**
    Creates a pretty-serializer
*/
InochiSerializer inCreatePrettySerializer() {
    import std.array: appender;
    import std.functional: forward;
    import std.range.primitives: put;

    auto app = appender!(char[]);
    return InochiSerializer((const(char)[] chars) => put(app, chars));
}

/**
    Creates a pretty-serializer
*/
InochiSerializerCompact inCreateCompactSerializer() {
    import std.array: appender;
    import std.functional: forward;
    import std.range.primitives: put;

    auto app = appender!(char[]);
    return InochiSerializerCompact((const(char)[] chars) => put(app, chars));
}

alias InochiSerializer = JsonSerializer!("\t", void delegate(const(char)[]) pure nothrow @safe);
alias InochiSerializerCompact = JsonSerializer!("", void delegate(const(char)[]) pure nothrow @safe);

string getString(Asdf data) {
    import std.array: appender;
    import std.functional: forward;
    import std.range.primitives: put;

    auto app = appender!(char[]);
    data.toString((const(char)[] chars) => put(app, chars));
    return cast(string)app.data;
}