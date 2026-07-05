/**
    Inochi2D WebAssembly Integration.

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.sys.wasm;
import ldc.attributes : llvmAttr;
import core.stdc.errno;

// dfmt off

version (WebAssembly):
extern (C) export @nogc nothrow:

int getErrno() {
    return errno;
}

int setErrno(int value) {
    errno = value;
    return errno;
}

// Set up WASM constructors.
extern void __wasm_call_ctors();
export void in_init() {
    __wasm_call_ctors();
}
