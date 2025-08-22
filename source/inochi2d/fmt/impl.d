module inochi2d.fmt.impl;


/**
    Array deserializer.
*/
void onDeserialize(T)(ref T dst, ref JSONValue object) 
if (is(T == U[], U)) {
    import std.range : ElementType;

    if (object.isJsonArray) {
        JSONValue[] arr = object.arrayNoRef;

        if (arr.length > 0) {
            dst.length = arr.length;
            
            foreach(i, ref JSONValue v; arr) {
                static if (is(ElementType!T : U[], U)) {
                    v.deserialize(dst[i]);
                } else static if (__traits(isIntegral, T)) {
                    switch(v.type) {
                        case JSONType.uinteger:
                            dst[i] = cast(T)v.uinteger;
                            break;
                        case JSONType.integer:
                            dst[i] = cast(T)v.integer;
                            break;
                        case JSONType.float_:
                            dst[i] = cast(T)v.floating;
                            break;
                        default:
                            break;
                    }
                } else static if (isDeserializable!T) {
                    dst[i].onDeserialize(v);
                }
            }
        }
    }
}