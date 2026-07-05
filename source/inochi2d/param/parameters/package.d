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
import inochi2d.param.bindings;
import inochi2d.param.utils;
import inochi2d.common;
import inochi2d.puppet;
import inochi2d.nodes;
import inochi2d.core;
import inochi2d.core.serde;

import numem;
import numem.core.memory;

import nulib.collections;
import nulib.string;

import numath;

/**
    The public parameter registry.
*/
__gshared TypeRegistry!Parameter in_param_registry;

public import inochi2d.param.parameters.param1d;
public import inochi2d.param.parameters.param2d;

/**
    Top-level parameter deserialization function.
*/
Parameter tryDeserializeParam(ref DataNode object, ref ModelState state) @nogc {
    if (state.doUpgrade08) {
        state.info(nstring("0.8->0.9: upgrading legacy parameter ", object["name"].text));
        auto param = object.tryGet!bool(state, "is_vec2", false) ?
            nogc_new!Parameter2D() : nogc_new!Parameter1D();

        param.deserialize(object, state);
        return param;
    }

    if (auto param = in_param_registry.tryCreateFrom(object)) {
        param.deserialize(object, state);
        return param;
    }

    state.warning(nstring("Encountered untyped parameter, ignoring..."));
    return null;
}

/**
    Parameters are configurable values that are used to drive mesh
        deformations, property overrides, and more.
*/
abstract
class Parameter : NuRefCounted, ISerializable, IDeserializable!ModelState {
protected:
@nogc:

    /**
        Serialize this parameter.
    */
    override
    void onSerialize(ref DataNode object) {
        object["guid"] = guid.toString()[];
        object["name"] = name[];
        // object["bindings"] = bindings.serialize();
    }

    /**
        Deserialize this parameter.
    */
    override
    void onDeserialize(ref DataNode object, ref ModelState state) {
        guid = object.tryGetGUID(state, "uuid");
        object.tryGetRef(state, name, "name");

        auto pbindings = "bindings" in object;
        if (pbindings && (*pbindings).isArray) {
            foreach (ref binding; (*pbindings).array) {
                this.bindings ~= binding.tryDeserializeBinding(state, this);
            }
        }
    }

    /**
        Finalizes the parameter.

        Params:
            puppet =    The parent puppet
            state =     The state of the deserializer.
    */
    void onFinalize(Puppet puppet, ref ModelState state) {
        foreach_reverse (i; 0 .. bindings.length) {
            if (auto binding = bindings[i]) {
                binding.finalize(puppet, state);
            } else {
                bindings.removeAt(i);
            }
        }
    }

public:

    /**
        The globally unique ID of this parameter.
    */
    GUID guid;

    /**
        The user-facing name of this parameter.
    */
    nstring name;

    /**
        Whether this parameter currently updates the model.
    */
    bool active = true;

    /**
        The bindings of this parameter to puppet nodes.
    */
    vector!ParameterBinding bindings;

    /**
        The dimensionality of the parameter.
    */
    abstract @property int dimensions();

    /**
        Counts of elements in each axis.
    */
    abstract @property uint[] elementCounts();

    /**
        The current value of the parameter.
    */
    abstract @property float[] currentValue();

    /**
        The lower bound of this parameter.
    */
    abstract @property float[] lowerBound();

    /**
        The upper bound of this parameter.
    */
    abstract @property float[] upperBound();

    /**
        Check whether this parameter has a binding to the given target.

        Params:
            node = 
            prop = 

        Returns:
            $(D true) if this parameter has a binding to the target,
            $(D false) otherwise.
    */
    bool hasBinding(Node node, string prop) {
        //foreach (ref binding; bindings) {
        //    if (binding.target.node is node && binding.target.prop == prop) {
        //        return true;
        //    }
        //}

        return false;
    }

    /**
        Check whether this parameter has any bindings to the given node.

        Params:
            node = 

        Returns:
            $(D true) if this parameter has any bindings to the node,
            $(D false) otherwise.
    */
    bool hasAnyBindingsTo(Node node) {
        //foreach (binding; bindings) {
        //    if (binding.target.node is node) {
        //        return true;
        //    }
        //}

        return false;
    }

    /**
        Serializes this parameter.
    */
    final void serialize(ref DataNode object) {
        this.onSerialize(object);
    }

    /**
        Deserializes this parameter.
    */
    final void deserialize(ref DataNode object, ref ModelState state) {
        this.onDeserialize(object, state);
    }

    /**
        Finalizes the parameter.

        Params:
            puppet =    The parent puppet
            state =     The state of the deserializer.
    */
    final void finalize(Puppet puppet, ref ModelState state) {
        this.onFinalize(puppet, state);
    }

    /**
        Update our bindings with the value of this parameter.
    */
    abstract void update();
}

enum ParameterAxis {
    /**
        Axis along rows (vertical).
    */
    rows = 0,

    /**
        Axis along columns (horizontal).
    */
    columns = 1,
}

enum ParameterMergeMode {
    /**
        Parameters are merged additively
    */
    additive = 0x00,

    /**
        Parameters are merged with a weighted average
    */
    weighted = 0x01,

    /**
        Parameters are merged multiplicatively
    */
    multiplicative = 0x02,

    /**
        Forces parameter to be given value
    */
    forced = 0x03,

    /**
        Merge mode is passthrough
    */
    passthrough = 0x04,
}

/**
    Gets a parameter merge mode from its string name.
*/
ParameterMergeMode toParameterMergeMode(string value) @nogc {
    switch (value) {
    case "additive":
    case "Additive":
        return ParameterMergeMode.additive;

    case "weighted":
    case "Weighted":
        return ParameterMergeMode.weighted;

    case "multiplicative":
    case "Multiplicative":
        return ParameterMergeMode.multiplicative;

    case "forced":
    case "Forced":
        return ParameterMergeMode.forced;

    default:
    case "passthrough":
    case "Passthrough":
        return ParameterMergeMode.passthrough;
    }
}

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
    auto cursor = points[0 .. $ - 1];
    while (cursor.length > 1) {
        if (pos < cursor[$ / 2]) {
            cursor = cursor[0 .. $ / 2];
        } else {
            cursor = cursor[$ / 2 .. $];
        }
    }

    // Pointer distance from points start to cursor start.
    return cast(ptrdiff_t)(&cursor[0] - &points[0]);
}
