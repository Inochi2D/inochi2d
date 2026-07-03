/**
    Specific Parameter Implementations

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)

    Authors:
        Luna Nielsen
        Mireille Arseneault
        Hoshino Lina
*/
module inochi2d.param.parameters;

public import inochi2d.param.parameters.param1d;
public import inochi2d.param.parameters.param2d;

/**
    Find the index and normal of the given position among the given points.

    Params:
        points = The set of points to search, must contain at least two values.
        pos = The position to search for among the given points.
        norm = The given position, normalized between its two adjacent points.

    Returns:
        The index of the point right *before* the given position,
        or $(D -1) if not found.
*/
ptrdiff_t searchPoints(float[] points, float pos, out float norm) pure @nogc {

    // Find index of given position.
    const index = searchPoints(points, pos);

    if (index >= 0) {
    
        // Normalize along two adjacent points.
        const lo = points[index];
        const hi = points[index + 1];
        norm = (pos - lo) / (hi - lo);
    }

    return index;
}

/**
    Find the index of the given position among the given points.

    Params:
        points = The set of points to search, must contain at least two values.
        pos = The position for which to search among the given points.

    Returns:
        The index of the point right *before* the given position,
        or $(D -1) if not found.
*/
ptrdiff_t searchPoints(float[] points, float pos) pure @nogc {
    assert(points.length >= 2, "Cannot search lists of points with fewer than 2 elements.");

    // Binary-search points list for our position.
    auto cursor = points[0..$ - 1];
    while (cursor.length > 1) {
        if (pos < cursor[$ / 2]) {
            cursor = cursor[0..$ / 2];
        } else {
            cursor = cursor[$ / 2..$];
        }
    }

    // Pointer distance from points start to cursor start.
    return cast(ptrdiff_t)(&cursor[0] - &points[0]);
}