/**
    Utility functions.

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)

    Authors:
        Luna Nielsen
*/
module inochi2d.param.utils;
import inochi2d.core.vector2d;
import inochi2d.core.serde;
import inochi2d.common;
import inochi2d.param;
import numath;
import nulib;
import numem;

/**
    Deserializes a legacy 0.8 style nested array to the new flat format.

    Params:
        object =    The DataNode to extract the data from.
        target =    The target to store the data within.
        state =     The state of the deserializer.
        dims =      The dimensionality expected.
*/
void deserialize08NestedArrays(T)(ref DataNode object, ref T target, ref ModelState state, vec2u dims) @nogc
        if (is(T == vector2d!U, U)) {
    import inochi2d.core.math.deform : Deformation;

    // Invalid array.
    if (!object.isArray) {
        state.error(nstring("expected array, got ", object.type.toTypeName, "!"));
        return;
    }

    target.resize(dims.x, dims.y);

    // The Y axis is shorter than expected.
    if (object.length < dims.y) {
        state.error("fewer elements were found in the y axis than were expected!");
        return;
    }

    // Iterate through all elements, adding them to the given index in the
    // target.
    size_t px = 0;
    size_t py = 0;
    foreach (ref DataNode elem; object.array) {

        // Not nested??
        if (!elem.isArray) {
            state.error(nstring("expected nested array, got ", elem.type.toTypeName, "!"));
            return;
        }

        // Too short?
        if (elem.length < dims.x) {
            state.error("fewer elements were found in the x axis than were expected!");
            return;
        }

        foreach (ref value; elem.array) {
            target[px, py] = value.deserialize!(T.DT)(state);
            px++;
        }
        py++;
        px = 0;
    }
}

/**
    Resizes the given vector2d to fit the element counts
    of the given parameter.

    Params:
        vec2d = The target vector2d.
        param = The parameter. 
*/
void resizeToParam(T)(ref T vec2d, Parameter param) {
    if (param.dimensions == 1) {
        vec2d.resize(1, param.elementCounts[0]);
    } else if (param.dimensions == 2) {
        vec2d.resize(param.elementCounts[0], param.elementCounts[1]);
    }
}

/**
    Interpolates between keypoints.
*/
T interpolateKeypoint(T)(ref vector2d!T values, vec2u index, vec2 norm) @nogc {
    return T.init;
}
