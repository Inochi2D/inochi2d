/**
    Inochi2D C FFI Error Handling.

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.cffi.eh;
import numem;

version (IN_DYNLIB)  :  //
//              ERROR HANDLING
//

/**
    Gets the last error.

    Returns:
        A string with the last error that occured,
        or $(D null).
*/
export
extern (C) const(char)* in_get_last_error() @nogc nothrow {
    return __in_last_error.ptr;
}

/**
    Internal function which sets the current active error.
*/
export
extern (C) void __in_set_error(string error) @nogc nothrow {
    __in_last_error = error;
}

/**
    Internal function which clears errors.
*/
export
extern (C) void __in_clear_error() @nogc nothrow {
    if (__in_last_error)
        nu_freea(__in_last_error);
}

private __gshared string __in_last_error;