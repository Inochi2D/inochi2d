/**
    Inochi2D C FFI

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.cffi;
import inochi2d.core.guid;
import numem;

version (IN_DYNLIB) :
extern (C) export @nogc:

/**
    A GUID
*/
alias in_guid_t = ubyte[GUID.sizeof];

/**
    A nil GUID.
*/
enum IN_GUID_NIL = GUID.nil;

/**
    Retains a reference to a Inochi2D Object.

    Params:
        obj = The object to retain.
    
    Returns:
        The object.
*/
void* in_retain(void* obj) {
    return cast(void*)(cast(NuRefCounted)obj).retain();
}

/**
    Releases a reference to a Inochi2D Object.

    Params:
        obj = The object to release.
    
    Returns:
        The object.
*/
void* in_release(void* obj) {
    return cast(void*)(cast(NuRefCounted)obj).release();
}