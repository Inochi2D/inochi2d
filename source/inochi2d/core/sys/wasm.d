/**
    Inochi2D WebAssembly Integration.

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.sys.wasm;
import ldc.attributes : llvmAttr;
import core.stdc.errno;

version(WebAssembly):

extern(C) export @nogc nothrow:

int getErrno() { return errno; }
int setErrno(int value) { errno = value; return errno; }