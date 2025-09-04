/**
    Inochi2D C FFI Error Handling.

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.cffi.eh;
import numem;

version(IN_DYNLIB):

//
//              ERROR HANDLING
//

/**
    Gets the last error.

    Returns:
        A string with the last error that occured,
        or $(D null).
*/
export
extern(C) const(char)* in_get_last_error() @nogc nothrow {
    return __in_last_error.ptr;
}

/**
    Internal function which sets the current active error.
*/
export
extern(C) void __in_set_error(Exception ex) @nogc nothrow {
    assumeNoThrowNoGC(&__in_set_error_fn, ex);
}

/**
    Internal function which clears errors.
*/
export
extern(C) void __in_clear_error() @nogc nothrow {

    // Delete old error message (if needed)
    if (__in_last_error.length > 0)
        nu_freea(__in_last_error);
}

// The last error.
private {
    __gshared string __in_last_error;
    void __in_set_error_fn(Exception ex) {
        import std.format : format;
        import numem.core.memory : nu_terminate;

        // Set the error message.
        __in_last_error = ex.toString().nu_dup;
        __in_last_error = __in_last_error.nu_terminate;
    }
}

//
//              DRT INIT
//


/// CRT CTOR
pragma(crt_constructor)
extern(C) private void in_crt_init() {
    import core.runtime : rt_init;
    assumeNoGC(&rt_init);
    __in_clear_error();
}

/// CRT DTOR
pragma(crt_destructor)
extern(C) private void in_crt_term() {
    import core.runtime : rt_term;
    assumeNoGC(&rt_term);
}