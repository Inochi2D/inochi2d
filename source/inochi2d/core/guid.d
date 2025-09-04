/**
    Inochi2D Unique IDs

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen, seagetch
*/
module inochi2d.core.guid;
import nulib.random;
import nulib.uuid;
import std.json;

/**
    A globally unique ID.
*/
alias GUID = UUID;


/**
    Creates a GUID from a legacy UUID.

    Params:
        legacyUUID = The legacy UUID to convert.
    
    Returns:
        A new GUID, with the time set to the legacy UUID, 
        and the last byte set to 255.
    
    Notes:
        You should ideally use GUIDs instead of UUIDs.
*/
GUID toGuid(uint legacyUUID) @nogc {
    return GUID(legacyUUID, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255);
}

/**
    Creates a new GUID.

    Returns:
        A new random GUID based on system time.
*/
GUID inNewGUID() @nogc {
    return GUID.createRandom(__i2d_uuid_random);
}

/**
    Tries to get a GUID from a JSON Object.

    Inochi2D has transitioned over to GUIDs,
    as such we convert the old 32 bit UUIDs into
    fake GUIDs if they're in use.

    Params:
        obj =       The object to get the GUID from.
        uuidKey =   The legacy UUID key to check for.
        guidKey =   The GUID key to check for.

    Returns:
        A GUID.
*/
GUID tryGetGUID(ref JSONValue obj, string uuidKey, string guidKey = "guid") {
    import inochi2d.core.format.serde : hasKey, tryGet, isScalar;
    if (obj.hasKey(uuidKey) && obj[uuidKey].isScalar)
        return obj.tryGet!uint(uuidKey).toGuid;
    else {
        return GUID(obj.tryGet!string(guidKey));
    }
}

/**
    Tries to get a GUID from a JSON Object.

    Params:
        obj =       The object to get the GUID from.
*/
GUID tryGetGUID(ref JSONValue obj) {
    import inochi2d.core.format.serde : tryGet, isScalar;
    return obj.isScalar ?
        obj.tryGet!uint(uint.max).toGuid :
        GUID(obj.str);
}

//
//          IMPLEMENTATION DETAILS.
//
private:

__gshared Random __i2d_uuid_random;
shared static this() {
    import core.time : MonoTime;
    import numem : nogc_new;

    __i2d_uuid_random = nogc_new!Random(MonoTime.currTime.ticks);
}