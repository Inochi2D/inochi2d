/*
    Inochi2D Rendering

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core;

public import inochi2d.core.serde;
public import inochi2d.core.render;
public import inochi2d.core.mesh;
public import inochi2d.core.guid;
public import inochi2d.core.math;
public import inochi2d.core.property;
public import inochi2d.core.registry;
public import inochi2d.core.memory;
public import inochi2d.core.mrange;
public import inochi2d.core.rlist;

import inochi2d.core.math;


/**
    Coerces input value to a slice.

    Params:
        v = The value to coerce.

    Returns:
        The given value coerced to a slice.
*/
auto coerceToSlice(T)(ref T v) @trusted @nogc nothrow {
    static if (is(T == U[], U)) {
        return v;
    } else static if (__traits(isStaticArray, T)) {
        return v[0..$];
    } else {
        return (&v)[0..1];
    }
}