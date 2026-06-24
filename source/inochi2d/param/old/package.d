/*
    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors:
    - Luna Nielsen
    - Hoshino Lina
	- Mireille Arseneault
*/
module inochi2d.param.old;
import inochi2d.puppet;
import inochi2d.nodes;
import inochi2d.core;
import inochi2d.core.serde;
import numem.core.memory;
import nulib.collections;
import nulib.string;
import numem;

public import inochi2d.param.old.binding;

enum ParamMergeMode {

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
    Gets a parameter merge mode from its string name
*/
ParamMergeMode toMergeMode(string value) @nogc {
    switch (value) {

    case "additive":
    case "Additive":
        return ParamMergeMode.additive;

    case "weighted":
    case "Weighted":
        return ParamMergeMode.weighted;

    case "multiplicative":
    case "Multiplicative":
        return ParamMergeMode.multiplicative;

    case "forced":
    case "Forced":
        return ParamMergeMode.forced;

    default:
    case "passthrough":
    case "Passthrough":
        return ParamMergeMode.passthrough;
    }
}

/**
    A parameter™
*/
class Parameter : NuRefCounted, ISerializable, IDeserializable {
private:
@nogc:

public:
    /**
        Unique ID of parameter
    */
    GUID guid;

    /**
        Name of the parameter
    */
    nstring name;

    /**
        Whether this parameter updates the model
    */
    bool active = true;

    /**
        The current parameter value
    */
    vec2 value = vec2(0);

    /**
        The previous internal value offset
    */
    vec2 lastInternal = vec2(0);

    /**
        Parameter merge mode
    */
    ParamMergeMode mergeMode;

    /**
        The default value
    */
    vec2 defaults = vec2(0);

    /**
        Whether the parameter is 2D
    */
    bool isVec2;

    /**
        The parameter's minimum bounds
    */
    vec2 min = vec2(0, 0);

    /**
        The parameter's maximum bounds
    */
    vec2 max = vec2(1, 1);

    /**
        Position of the keypoints along each axis
    */
    vector!float[2] axisPoints;

    /**
        Binding to targets
    */
    vector!ParameterBinding bindings;

    /**
        The value normalized to the internal range (0.0->1.0)
    */
    @property vec2 normalizedValue() @nogc => this.mapValue(value);
    @property void normalizedValue(vec2 value) @nogc {
        this.value = vec2(
                value.x * (max.x - min.x) + min.x,
                value.y * (max.y - min.y) + min.y
        );
    }

    ~this() {
        static foreach (axis; 0 .. axisPoints.length) {
            axisPoints[axis].clear();
        }
    }

    /**
        For serialization
    */
    this() {
        static foreach (axis; 0 .. axisPoints.length) {
            this.axisPoints[axis].resize(2);
            this.axisPoints[axis][0] = 0;
            this.axisPoints[axis][1] = 1;
        }
    }

    /**
        Create new parameter
    */
    this(string name, bool isVec2) {
        this();
        this.guid = inNewGUID();
        this.name = name;
        this.isVec2 = isVec2;
    }

    /**
        Clone this parameter
    */
    Parameter dup() {
        Parameter newParam = nogc_new!Parameter(nstring(name, " (Copy)").take(), isVec2);

        newParam.min = min;
        newParam.max = max;
        newParam.axisPoints = axisPoints.nu_dup;

        foreach (binding; bindings) {
            ParameterBinding newBinding = newParam.createBinding(
                    binding.getNode(),
                    binding.getName(),
                    false
            );
            newBinding.interpolateMode = binding.interpolateMode;
            foreach (x; 0 .. axisPointCount(0)) {
                foreach (y; 0 .. axisPointCount(1)) {
                    binding.copyKeypointToBinding(vec2u(x, y), newBinding, vec2u(x, y));
                }
            }
            newParam.addBinding(newBinding);
        }

        return newParam;
    }

    /**
        Serializes a parameter
    */
    void onSerialize(ref DataNode object, bool recursive = true) {

        auto selfGuid = guid.toString();
        object["guid"] = selfGuid[];
        object["name"] = name[];
        object["is_vec2"] = isVec2;
        object["is_vec2"] = isVec2;
        object["min"] = min.serialize();
        object["max"] = max.serialize();
        object["defaults"] = defaults.serialize();
        object["axis_points"] = axisPoints.serialize();
        object["merge_mode"] = cast(uint)mergeMode;

        object["bindings"] = DataNode.createArray();
        foreach (ref binding; bindings) {
            auto bindingNode = DataNode.createObject();
            binding.onSerialize(bindingNode);

            object["bindings"] ~= bindingNode;
        }
    }

    /**
        Deserializes a parameter
    */
    void onDeserialize(ref DataNode object) {

        this.guid = object.tryGetGUID("uuid", "guid");
        object.tryGetRef(name, "name");
        object.tryGetRef(isVec2, "is_vec2");
        object.tryGetRef(min, "min");
        object.tryGetRef(max, "max");
        object.tryGetRef(defaults, "defaults");
        mergeMode = object.tryGet!string("merge_mode").toMergeMode();

        if ("axis_points" in object && object["axis_points"].array) {
            foreach (i, ref axis; object["axis_points"].array) {
                if (i > axisPoints.length)
                    break;

                this.axisPoints[i].resize(axis.length);
                axis.deserialize(axisPoints[i]);
            }
        }

        if ("bindings" in object && object["bindings"].isArray) {
            foreach (ref child; object["bindings"].array) {

                // Skip empty children
                if (string paramName = child.tryGet!string("param_name", null)) {

                    if (paramName == "deform") {
                        auto binding = nogc_new!DeformationParameterBinding(this);
                        child.deserialize(binding);
                        bindings ~= cast(ParameterBinding)binding;
                    } else {
                        auto binding = nogc_new!ValueParameterBinding(this);
                        child.deserialize(binding);
                        bindings ~= cast(ParameterBinding)binding;
                    }
                }
            }
        }
    }

    /**
        Finalize loading of parameter
    */
    void finalize(Puppet puppet) {
        this.value = defaults;
        foreach_reverse (i; 0 .. bindings.length) {
            if (puppet.find!Node(bindings[i].getNodeGUID())) {
                bindings[i].finalize(puppet);
                continue;
            }

            bindings.removeAt(i);
        }
    }

    void findOffset(vec2 offset, out vec2u index, out vec2 outOffset) {
        void interpAxis(uint axis, float val, out uint index, out float offset) {
            float[] pos = axisPoints[axis];

            foreach (i; 0 .. pos.length - 1) {
                if (pos[i + 1] > val || i == (pos.length - 2)) {
                    index = cast(uint)i;
                    offset = (val - pos[i]) / (pos[i + 1] - pos[i]);
                    return;
                }
            }
        }

        interpAxis(0, offset.x, index.x, outOffset.x);
        if (isVec2)
            interpAxis(1, offset.y, index.y, outOffset.y);
    }

    void update() {
        vec2u index;
        vec2 offset_;

        if (!active)
            return;

        findOffset(this.mapValue(value), index, offset_);
        foreach (binding; bindings) {
            binding.apply(index, offset_);
        }
    }

    void pushIOffset(vec2 offset, ParamMergeMode mode = ParamMergeMode.passthrough, float weight = 1) {
        this.value = offset;
    }

    void pushIOffsetAxis(int axis, float offset, ParamMergeMode mode = ParamMergeMode.passthrough, float weight = 1) {
        this.value.vector[axis] = offset;
    }

    /**
        Get number of points for an axis
    */
    uint axisPointCount(uint axis = 0) @nogc {
        return cast(uint)axisPoints[axis].length;
    }

    /**
        Move an axis point to a new offset
    */
    void moveAxisPoint(uint axis, uint oldidx, float newoff) {
        assert(oldidx > 0 && oldidx < this.axisPointCount(axis) - 1, "invalid point index");
        assert(newoff > 0 && newoff < 1, "offset out of bounds");
        if (isVec2)
            assert(axis <= 1, "bad axis");
        else
            assert(axis == 0, "bad axis");

        // Find the index at which to insert
        uint index;
        for (index = 1; index < axisPoints[axis].length; index++) {
            if (axisPoints[axis][index + 1] > newoff)
                break;
        }

        if (oldidx != index) {
            nu_swap(axisPoints[axis][oldidx], axisPoints[axis][index]);
        }

        // Tell all bindings to reinterpolate
        foreach (binding; bindings) {
            binding.moveKeypoints(axis, oldidx, index);
        }
    }

    /**
        Add a new axis point at the given offset
    */
    void insertAxisPoint(uint axis, float off) {
        assert(off > 0 && off < 1, "offset out of bounds");
        if (isVec2)
            assert(axis <= 1, "bad axis");
        else
            assert(axis == 0, "bad axis");

        // Find the index at which to insert
        uint index;
        for (index = 1; index < axisPoints[axis].length; index++) {
            if (axisPoints[axis][index] > off)
                break;
        }

        // Insert it into the position list
        axisPoints[axis][index] = off;

        // Tell all bindings to insert space into their arrays
        foreach (binding; bindings) {
            binding.insertKeypoints(axis, index);
        }
    }

    /**
        Delete a specified axis point by index
    */
    void deleteAxisPoint(uint axis, uint index) {
        if (isVec2)
            assert(axis <= 1, "bad axis");
        else
            assert(axis == 0, "bad axis");

        assert(index > 0, "cannot delete axis point at 0");
        assert(index < (axisPoints[axis].length - 1), "cannot delete axis point at 1");

        // Remove the keypoint
        axisPoints[axis].removeAt(index);

        // Tell all bindings to remove it from their arrays
        foreach (binding; bindings) {
            binding.deleteKeypoints(axis, index);
        }
    }

    /**
        Flip the mapping across an axis
    */
    void reverseAxis(uint axis) {
        nu_reverse(axisPoints[axis][0 .. $]);
        foreach (ref i; axisPoints[axis]) {
            i = 1 - i;
        }
        foreach (binding; bindings) {
            binding.reverseAxis(axis);
        }
    }

    /**
        Get the offset (0..1) of a specified keypoint index
    */
    vec2 getKeypointOffset(vec2u index) {
        return vec2(axisPoints[0][index.x], axisPoints[1][index.y]);
    }

    /**
        Get the value at a specified keypoint index
    */
    vec2 getKeypointValue(vec2u index) {
        return unmapValue(getKeypointOffset(index));
    }

    /**
        Maps an input value to an offset (0.0->1.0)
    */
    vec2 mapValue(vec2 value) @nogc {
        vec2 range = max - min;
        vec2 tmp = (value - min);
        vec2 off = vec2(tmp.x / range.x, tmp.y / range.y);

        vec2 clamped = vec2(
                clamp(off.x, 0, 1),
                clamp(off.y, 0, 1),
        );
        return clamped;
    }

    /**
        Maps an offset (0.0->1.0) to a value
    */
    vec2 unmapValue(vec2 offset) @nogc {
        vec2 range = max - min;
        return vec2(range.x * offset.x, range.y * offset.y) + min;
    }

    /**
        Maps an input value to an offset (0.0->1.0) for an axis
    */
    float mapAxis(uint axis, float value) {
        vec2 input = min;
        if (axis == 0)
            input.x = value;
        else
            input.y = value;
        vec2 output = mapValue(input);
        if (axis == 0)
            return output.x;
        else
            return output.y;
    }

    /**
        Maps an internal value (0.0->1.0) to the input range for an axis
    */
    float unmapAxis(uint axis, float offset) {
        vec2 input = min;
        if (axis == 0)
            input.x = offset;
        else
            input.y = offset;
        vec2 output = unmapValue(input);
        if (axis == 0)
            return output.x;
        else
            return output.y;
    }

    /**
        Gets the axis point closest to a given offset
    */
    uint getClosestAxisPointIndex(uint axis, float offset) {
        uint closestPoint = 0;
        float closestDist = float.infinity;

        foreach (i, pointVal; axisPoints[axis]) {
            float dist = abs(pointVal - offset);
            if (dist < closestDist) {
                closestDist = dist;
                closestPoint = cast(uint)i;
            }
        }

        return closestPoint;
    }

    /**
        Find the keypoint closest to the current value
    */
    vec2u findClosestKeypoint() {
        return findClosestKeypoint(value);
    }

    /**
        Find the keypoint closest to a value
    */
    vec2u findClosestKeypoint(vec2 value) {
        vec2 mapped = mapValue(value);
        uint x = getClosestAxisPointIndex(0, mapped.x);
        uint y = getClosestAxisPointIndex(1, mapped.y);

        return vec2u(x, y);
    }

    /**
        Find the keypoint closest to the current value
    */
    vec2 getClosestKeypointValue() {
        return getKeypointValue(findClosestKeypoint());
    }

    /**
        Find the keypoint closest to a value
    */
    vec2 getClosestKeypointValue(vec2 value) {
        return getKeypointValue(findClosestKeypoint(value));
    }

    /**
        Find a binding by node ref and name
    */
    ParameterBinding getBinding(Node n, string bindingName) {
        foreach (ref binding; bindings) {
            if (binding.getNode() !is n)
                continue;
            if (binding.getName == bindingName)
                return binding;
        }
        return null;
    }

    /**
        Check if a binding exists for a given node and name
    */
    bool hasBinding(Node n, string bindingName) {
        foreach (ref binding; bindings) {
            if (binding.getNode() !is n)
                continue;
            if (binding.getName == bindingName)
                return true;
        }
        return false;
    }

    /**
        Check if any bindings exists for a given node
    */
    bool hasAnyBinding(Node n) {
        foreach (ref binding; bindings) {
            if (binding.getNode() is n)
                return true;
        }
        return false;
    }

    /**
        Create a new binding (without adding it) for a given node and name
    */
    ParameterBinding createBinding(Node n, string bindingName, bool setZero = true) @nogc {
        ParameterBinding b;
        if (bindingName == "deform") {
            b = nogc_new!DeformationParameterBinding(this, n, bindingName);
        } else {
            b = nogc_new!ValueParameterBinding(this, n, bindingName);
        }

        if (setZero) {
            vec2u zeroIndex = findClosestKeypoint(vec2(0, 0));
            vec2 zero = getKeypointValue(zeroIndex);
            if (abs(zero.x) < 0.001 && abs(zero.y) < 0.001)
                b.reset(zeroIndex);
        }

        return b;
    }

    /**
        Find a binding if it exists, or create and add a new one, and return it
    */
    ParameterBinding getOrAddBinding(Node n, string bindingName, bool setZero = true) {
        ParameterBinding binding = getBinding(n, bindingName);
        if (binding is null) {
            binding = createBinding(n, bindingName, setZero);
            addBinding(binding);
        }
        return binding;
    }

    /**
        Add a new binding (must not exist)
    */
    void addBinding(ParameterBinding binding) {
        assert(!hasBinding(binding.getNode, binding.getName));
        bindings ~= binding;
    }

    /**
        Remove an existing binding by ref
    */
    void removeBinding(ParameterBinding binding) {
        bindings.remove(binding);
    }
}