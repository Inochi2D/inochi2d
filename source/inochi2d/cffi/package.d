/**
    Inochi2D C FFI

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.cffi;
import numem;

version(IN_DYNLIB):
extern(C) export @nogc:

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