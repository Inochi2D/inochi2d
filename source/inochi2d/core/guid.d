/**
    Inochi2D Unique IDs

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
        seagetch
*/
module inochi2d.core.guid;
import inochi2d.core.serde;
import nulib.random;
import nulib.uuid;

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
GUID tryGetGUID(ref DataNode obj, string uuidKey, string guidKey = "guid") @nogc {
    if (uuidKey in obj && obj[uuidKey].isNumber)
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
GUID tryGetGUID(ref DataNode obj) @nogc {
    return obj.isNumber ?
        obj.tryGet!uint(uint.max).toGuid : GUID(obj.text);
}

//
//          IMPLEMENTATION DETAILS.
//
private:

__gshared Random __i2d_uuid_random;
pragma(crt_constructor)
export extern(C) void __i2d_init_random() {
    import numem : nogc_new;
    __i2d_uuid_random = nogc_new!Random(0);
}
