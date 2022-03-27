/*
    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors:
    - Luna Nielsen
    - Asahi Lina
*/
module inochi2d.core.param;
import inochi2d.fmt.serialize;
import inochi2d.math.serialization;
import inochi2d.core;
import inochi2d.math;
import std.exception;
import std.array;
import std.algorithm.mutation;
import std.stdio;

public import inochi2d.core.param.binding;

/**
    A parameter
*/
class Parameter {
public:
    /**
        Unique ID of parameter
    */
    uint uuid;

    /**
        Name of the parameter
    */
    string name;

    /**
        Optimized indexable name generated at runtime

        DO NOT SERIALIZE THIS.
    */
    string indexableName;

    /**
        The current parameter value
    */
    vec2 value = vec2(0);

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
    float[][2] axisPoints = [[0, 1], [0, 1]];

    /**
        Binding to targets
    */
    ParameterBinding[] bindings;

    /**
        Gets the value normalized to the internal range (0.0->1.0)
    */
    vec2 normalizedValue() {
        return this.mapValue(value);
    }

    /**
        Sets the value normalized up from the internal range (0.0->1.0)
        to the user defined range.
    */
    void normalizedValue(vec2 value) {
        this.value = vec2(
            value.x * (max.x-min.x) + min.x,
            value.y * (max.y-min.y) + min.y
        );
    }

    /**
        For serialization
    */
    this() { }

    /**
        Unload UUID on clear
    */
    ~this() {
        inUnloadUUID(this.uuid);
    }

    /**
        Create new parameter
    */
    this(string name, bool isVec2) {
        this.uuid = inCreateUUID();
        this.name = name;
        this.isVec2 = isVec2;
        if (!isVec2)
            axisPoints[1] = [0];
        
        this.makeIndexable();
    }

    /**
        Serializes a parameter
    */
    void serialize(S)(ref S serializer) {
        auto state = serializer.objectBegin;
            serializer.putKey("uuid");
            serializer.putValue(uuid);
            serializer.putKey("name");
            serializer.putValue(name);
            serializer.putKey("is_vec2");
            serializer.putValue(isVec2);
            serializer.putKey("min");
            min.serialize(serializer);
            serializer.putKey("max");
            max.serialize(serializer);
            serializer.putKey("axis_points");
            serializer.serializeValue(axisPoints);
            serializer.putKey("bindings");
            auto arrstate = serializer.arrayBegin();
                foreach(binding; bindings) {
                    serializer.elemBegin();
                    binding.serializeSelf(serializer);
                }
            serializer.arrayEnd(arrstate);
        serializer.objectEnd(state);
    }

    /**
        Deserializes a parameter
    */
    SerdeException deserializeFromFghj(Fghj data) {
        data["uuid"].deserializeValue(this.uuid);
        data["name"].deserializeValue(this.name);
        if (!data["is_vec2"].isEmpty) data["is_vec2"].deserializeValue(this.isVec2);
        if (!data["min"].isEmpty) min.deserialize(data["min"]);
        if (!data["max"].isEmpty) max.deserialize(data["max"]);
        if (!data["axis_points"].isEmpty) data["axis_points"].deserializeValue(this.axisPoints);

        if (!data["bindings"].isEmpty) {
            foreach(Fghj child; data["bindings"].byElement) {
                
                // Skip empty children
                if (child["param_name"].isEmpty) continue;

                string paramName;
                child["param_name"].deserializeValue(paramName);

                if (paramName == "deform") {
                    auto binding = new DeformationParameterBinding(this);
                    binding.deserializeFromFghj(child);
                    bindings ~= binding;
                } else {
                    auto binding = new ValueParameterBinding(this);
                    binding.deserializeFromFghj(child);
                    bindings ~= binding;
                }
            }
        }

        return null;
    }

    /**
        Finalize loading of parameter
    */
    void finalize(Puppet puppet) {
        this.makeIndexable();
        foreach(binding; bindings) {
            binding.finalize(puppet);
        }
    }

    void findOffset(vec2 offset, out vec2u index, out vec2 outOffset) {
        void interpAxis(uint axis, float val, out uint index, out float offset) {
            float[] pos = axisPoints[axis];

            foreach(i; 0..pos.length - 1) {
                if (pos[i + 1] > val || i == (pos.length - 2)) {
                    index = cast(uint)i;
                    offset = (val - pos[i]) / (pos[i + 1] - pos[i]);
                    return;
                }
            }
        }

        interpAxis(0, offset.x, index.x, outOffset.x);
        if (isVec2) interpAxis(1, offset.y, index.y, outOffset.y);
    }

    void update() {
        vec2u index;
        vec2 offset;

        findOffset(normalizedValue, index, offset);
        foreach(binding; bindings) {
            binding.apply(index, offset);
        }
    }

    /**
        Get number of points for an axis
    */
    uint axisPointCount(uint axis = 0) {
        return cast(uint)axisPoints[axis].length;
    }

    /**
        Move an axis point to a new offset
    */
    void moveAxisPoint(uint axis, uint oldidx, float newoff) {
        assert(oldidx > 0 && oldidx < this.axisPointCount(axis)-1, "invalid point index");
        assert(newoff > 0 && newoff < 1, "offset out of bounds");
        if (isVec2)
            assert(axis <= 1, "bad axis");
        else
            assert(axis == 0, "bad axis");

        // Find the index at which to insert
        uint index;
        for(index = 1; index < axisPoints[axis].length; index++) {
            if (axisPoints[axis][index+1] > newoff)
                break;
        }
        
        if (oldidx != index) {
            // BUG: Apparently deleting the oldindex and replacing it with newindex causes a crash.

            // Insert it into the new position in the list
            auto swap = axisPoints[oldidx];
            axisPoints[axis] = axisPoints[axis].remove(oldidx);
            axisPoints[axis].insertInPlace(index, swap);
            writeln("after move ", this.axisPointCount(0));
        }

        // Tell all bindings to reinterpolate
        foreach(binding; bindings) {
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
        for(index = 1; index < axisPoints[axis].length; index++) {
            if (axisPoints[axis][index] > off)
                break;
        }

        // Insert it into the position list
        axisPoints[axis].insertInPlace(index, off);

        // Tell all bindings to insert space into their arrays
        foreach(binding; bindings) {
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
        axisPoints[axis] = axisPoints[axis].remove(index);

        // Tell all bindings to remove it from their arrays
        foreach(binding; bindings) {
            binding.deleteKeypoints(axis, index);
        }
    }

    /**
        Flip the mapping across an axis
    */
    void reverseAxis(uint axis) {
        axisPoints[axis].reverse();
        foreach(ref i; axisPoints[axis]) {
            i = 1 - i;
        }
        foreach(binding; bindings) {
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
    vec2 mapValue(vec2 value) {
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
    vec2 unmapValue(vec2 offset) {
        vec2 range = max - min;
        return vec2(range.x * offset.x, range.y * offset.y) + min;
    }

    /**
        Maps an input value to an offset (0.0->1.0) for an axis
    */
    float mapAxis(uint axis, float value) {
        vec2 input = min;
        if (axis == 0) input.x = value;
        else input.y = value;
        vec2 output = mapValue(input);
        if (axis == 0) return output.x;
        else return output.y;
    }

    /**
        Maps an internal value (0.0->1.0) to the input range for an axis
    */
    float unmapAxis(uint axis, float offset) {
        vec2 input = min;
        if (axis == 0) input.x = offset;
        else input.y = offset;
        vec2 output = unmapValue(input);
        if (axis == 0) return output.x;
        else return output.y;
    }

    /**
        Gets the axis point closest to a given offset
    */
    uint getClosestAxisPointIndex(uint axis, float offset) {
        uint closestPoint = 0;
        float closestDist = float.infinity;

        foreach(i, pointVal; axisPoints[axis]) {
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
        foreach(ref binding; bindings) {
            if (binding.getNode() != n) continue;
            if (binding.getName == bindingName) return binding;
        }
        return null;
    }

    /**
        Check if a binding exists for a given node and name
    */
    bool hasBinding(Node n, string bindingName) {
        foreach(ref binding; bindings) {
            if (binding.getNode() != n) continue;
            if (binding.getName == bindingName) return true;
        }
        return false;
    }

    /**
        Create a new binding (without adding it) for a given node and name
    */
    ParameterBinding createBinding(Node n, string bindingName, bool setZero = true) {
        ParameterBinding b;
        if (bindingName == "deform") {
            b = new DeformationParameterBinding(this, n, bindingName);
        } else {
            b = new ValueParameterBinding(this, n, bindingName);
        }

        vec2u zeroIndex = findClosestKeypoint(vec2(0, 0));
        vec2 zero = getKeypointValue(zeroIndex);
        if (abs(zero.x) < 0.001 && abs(zero.y) < 0.001) b.reset(zeroIndex);

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
        import std.algorithm.searching : countUntil;
        import std.algorithm.mutation : remove;
        ptrdiff_t idx = bindings.countUntil(binding);
        if (idx >= 0) {
            bindings = bindings.remove(idx);
        }
    }

    void makeIndexable() {
        import std.uni : toLower;
        indexableName = name.toLower;
    }
}