/**
    Serializable parameter configuration for values that drive puppets.

    Copyright © 2026, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors:
    - Luna Nielsen
    - Mireille Arseneault
    - Hoshino Lina
*/
module inochi2d.param.parameter;
import inochi2d.param.binding;
import inochi2d.puppet;
import inochi2d.nodes;
import inochi2d.core;
import inochi2d.core.serde;

import numem;
import numem.core.memory;

import nulib.collections;
import nulib.string;

import inmath;

/**
    Parameters are configurable values that are used to drive mesh
        deformations, property overrides, and more.
*/
abstract
class Parameter : NuRefCounted, ISerializable, IDeserializable {
public:
@nogc:
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
        Check whether this parameter has a binding to the given target.

        Params:
            node = 
            prop = 

        Returns:
            $(D true) if this parameter has a binding to the target,
            $(D false) otherwise.
    */
    bool hasBinding(Node node, string prop) {
        foreach (ref binding; bindings) {
            if (binding.target.node is node && binding.target.prop == prop) {
                return true;
            }
        }

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
        foreach (binding; bindings) {
            if (binding.target.node is node) {
                return true;
            }
        }

        return false;
    }

    /**
        Bind to a puppet, clearing dangling bindings in the process.
    */
    void bind(Puppet puppet) {
        foreach_reverse (i; 0 .. bindings.length) {
            ref binding = bindings[i];
            if (puppet.find!Node(binding.nodeId)) {
                binding.bind(puppet);
            } else {
                bindings.removeAt(i);
            }
        }
    }

    /**
        Serialize this parameter.
    */
    override
    void onSerialize(ref DataNode object, bool) {
        object["guid"] = guid.toString()[];
        object["name"] = name[];
        // object["bindings"] = bindings.serialize();
    }

    /**
        Deserialize this parameter.
    */
    override
    void onDeserialize(ref DataNode object) {
        guid = object.tryGetGUID("uuid");
        object.tryGetRef(name, "name");

        if (auto bindings = "bindings" in object) {
            foreach (ref binding; bindings.array) {
                this.bindings ~= tryGetBinding(binding, this);
            }
        }

        // Migrate old way of differentiating 1D/2D parameters.
        if (auto isVec2 = "is_vec2" in object) {
            object["axes"] = cast(uint)(isVec2.boolean ? 2 : 1);
        }

        // Migrate old way of storing keypoints.
        if (auto axes = "axis_points" in object) {
            switch (object.tryGet!uint("axes")) {
                case 1:
                    auto axis1 = axes.array[0];
                    object["points"] = axis1;
                    break;

                case 2:
                    auto axis1 = axes.array[0];
                    auto axis2 = axes.array[1];
                    object["hpoints"] = axis1;
                    object["vpoints"] = axis2;
                    break;

                default:
                    assert(false, "Invalid number of point axes");
                    break;
            }
        }
    }

    /**
        Update our bindings with the value of this parameter.
    */
    abstract void updateBindings();
}

/**
    1D variant of a parameter.
*/
class Parameter1D : Parameter {
public:
@nogc:
    /**
        The current value of this parameter.
    */
    float value = 0;

    /**
        The previous value of this parameter.
    */
    float prev = 0;

    /**
        The default value of this parameter.
    */
    float defaults = 0;

    /**
        The lower bound of this parameter.
    */
    float min = 0;

    /**
        The upper bound of this parameter.
    */
    float max = 1;

    /**
        Our keypoints' positions.
    */
    vector!float points;

    /**
        Construct a new named parameter.
    */
    this(string name) {
        const float[2] points_init = [0, 1];
        points = points_init;
        guid = inNewGUID();
        this.name = name;
    }

    /**
        Force this parameter to take on the given value.

        Params:
            value = The new value this parameter will take on.
    */
    void pushValue(float value) {
        this.value = value;
    }

    /**
        Find the keypoint index of the given position, as well as its normal.

        Params:
            pos = A position along our keypoints. Must be within min & max.
            norm = The given position, normalized within its keypoint.

        Returns:
            The index of the keypoint the given position falls on.
    */
    uint findKeypointAndNormal(float pos, out float norm) {
        assert(pos >= min && pos <= max);
        return searchPoints(points, pos, norm);
    }

    /**
        Normalize the given position between min & max.
    */
    float normalize(float pos) const {
        return (pos - min) / (max - min);
    }

    /**
        Linearly interpolate from min to max by the given value.
    */
    float lerp(float norm) const {
        return .lerp(min, max, norm);
    }

    /**
        Update our bindings with the value of this parameter.
    */
    override
    void updateBindings() {
        if (!active)
            return;

        float norm;
        uint index = findKeypointAndNormal(value, norm);

        foreach (binding; bindings) {
            binding.apply(vec2u(index, 0), vec2(norm, 0));
        }
    }

    /**
        Serialize this parameter.
    */
    override
    void onSerialize(ref DataNode object, bool) {
        super.onSerialize(object, false);
        object["axes"] = cast(uint)1;
        object["min"] = min.serialize();
        object["max"] = max.serialize();
        object["defaults"] = defaults.serialize();
        object["points"] = points.serialize();
    }

    /**
        Deserialize this parameter.
    */
    override
    void onDeserialize(ref DataNode object) {
        super.onDeserialize(object);
        assert(object["axes"] == 1);
        object.tryGetRef(min, "min");
        object.tryGetRef(max, "max");
        object.tryGetRef(defaults, "defaults");
        object.tryGetRef(points, "points");
    }

    /**
        Bind to a puppet.
    */
    override
    void bind(Puppet puppet) {
        value = defaults;
        super.bind(puppet);
    }
}

/**
    2D variant of a parameter.
*/
class Parameter2D : Parameter {
public:
@nogc:
    /**
        The current value of this parameter.
    */
    vec2 value = vec2(0, 0);

    /**
        The previous value of this parameter.
    */
    vec2 prev = vec2(0, 0);

    /**
        The default value of this parameter.
    */
    vec2 defaults = vec2(0, 0);

    /**
        The lower bounds of this parameter.
    */
    vec2 min = vec2(0, 0);

    /**
        The upper bounds of this parameter.
    */
    vec2 max = vec2(1, 1);

    /**
        Our horizontal keypoints' positions.
    */
    vector!float hpoints;

    /**
        Our vertical keypoints' positions.
    */
    vector!float vpoints;

    /**
        Construct a new named parameter.
    */
    this(string name) {
        const float[2] points_init = [0, 1];
        hpoints = points_init;
        vpoints = points_init;
        guid = inNewGUID();
        this.name = name;
    }

    /**
        Update our bindings with the value of this parameter.
    */
    override
    void updateBindings() {
        if (!active)
            return;

        vec2 norm;
        vec2u index = findKeypointAndNormal(value, norm);

        foreach (binding; bindings) {
            binding.apply(index, norm);
        }
    }

    /**
        Force this parameter to take on the given value.

        Params:
            value = The new value this parameter will take on.
    */
    void pushValue(vec2 value) {
        this.value = value;
    }

    /**
        Force this parameter to take on the given value.

        Params:
            axis  = The axis along which the value is set.
            value = The new value this parameter will take on.
    */
    void pushValue(ParameterAxis axis, float value) {
        final switch (axis) {
            case ParameterAxis.rows:
                this.value.y = value;
                break;

            case ParameterAxis.columns:
                this.value.x = value;
                break;
        }
    }

    /**
        Find the keypoint index of the given position, as well as its normal.

        Params:
            pos = A position along our keypoints. Must be within min & max.
            norm = The given position, normalized within its keypoint.

        Returns:
            The index of the keypoint the given position falls on.
    */
    vec2u findKeypointAndNormal(vec2 pos, out vec2 norm) {
        assert(pos.x >= min.x && pos.x <= max.x);
        assert(pos.y >= min.y && pos.y <= max.y);
        const x = searchPoints(hpoints, pos.x, norm.x);
        const y = searchPoints(vpoints, pos.y, norm.y);
        return vec2u(x, y);
    }

    /**
        Normalize the given position memberwise between min & max.
    */
    vec2 normalize(vec2 pos) const {
        const x = (pos.x - min.x) / (max.x - min.x);
        const y = (pos.y - min.y) / (max.y - min.y);
        return vec2(x, y);
    }

    /**
        Linearly interpolate min & max by the given value.
    */
    vec2 lerp(vec2 norm) const {
        const x = .lerp(min.x, max.x, norm.x);
        const y = .lerp(min.y, max.y, norm.y);
        return vec2(x, y);
    }

    /**
        Serialize this parameter.
    */
    override
    void onSerialize(ref DataNode object, bool) {
        super.onSerialize(object, false);
        object["axes"] = cast(uint)2;
        object["min"] = min.serialize();
        object["max"] = max.serialize();
        object["defaults"] = defaults.serialize();
        object["hpoints"] = hpoints.serialize();
        object["vpoints"] = vpoints.serialize();
    }

    /**
        Deserialize this parameter.
    */
    override
    void onDeserialize(ref DataNode object) {
        super.onDeserialize(object);
        assert(object["axes"] == 2);
        object.tryGetRef(min, "min");
        object.tryGetRef(max, "max");
        object.tryGetRef(defaults, "defaults");
        object.tryGetRef(hpoints, "hpoints");
        object.tryGetRef(vpoints, "vpoints");
    }

    /**
        Bind to a puppet.
    */
    override
    void bind(Puppet puppet) {
        value = defaults;
        super.bind(puppet);
    }
}

/**
    Deserialize a parameter depending on its shape.
*/
Parameter tryGetParameter(ref DataNode object) @nogc {
    if (object.tryGet!bool("is_vec2") || object.tryGet!uint("axes") == 2) {
        auto param = nogc_new!Parameter2D(null);
        object.deserialize(param);
        return cast(Parameter)param;
    } else {
        auto param = nogc_new!Parameter1D(null);
        object.deserialize(param);
        return cast(Parameter)param;
    }

    return null;
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
        The index of the point right *before* the given position.
*/
private uint searchPoints(float[] points, float pos, out float norm) pure @nogc {
    // Find index of given position.
    const index = searchPoints(points, pos);

    // Normalize along two adjacent points.
    const lo = points[index];
    const hi = points[index + 1];
    norm = (pos - lo) / (hi - lo);

    return index;
}

/**
    Find the index of the given position among the given points.

    Params:
        points = The set of points to search, must contain at least two values.
        pos = The position for which to search among the given points.

    Returns:
        The index of the point right *before* the given position.
*/
private uint searchPoints(float[] points, float pos) pure @nogc {
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
    return cast(uint)(&cursor[0] - &points[0]);
}