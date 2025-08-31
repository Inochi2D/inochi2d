module inochi2d.core.format.serde.serializers;
import inochi2d.core.math;
import inochi2d.core;
import inmath.util;
import std.json;
import std.traits;


/**
    Whether type T can be serialized.
*/
enum isSerializable(T) =
    is(T : ISerializable) || 
    is(typeof((ref JSONValue obj) { T a; a.onSerialize(obj); }));

/**
    Interface for classes that can be serialized to JSON with custom code
*/
interface ISerializable {

    /**
        Custom serializer function
    */
    void onSerialize(ref JSONValue object);
}

