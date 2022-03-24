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
    SerdeException deserializeFromAsdf(Asdf data) {
        data["uuid"].deserializeValue(this.uuid);
        data["name"].deserializeValue(this.name);
        if (!data["is_vec2"].isEmpty) data["is_vec2"].deserializeValue(this.isVec2);
        if (!data["min"].isEmpty) min.deserialize(data["min"]);
        if (!data["max"].isEmpty) max.deserialize(data["max"]);
        if (!data["axis_points"].isEmpty) data["axis_points"].deserializeValue(this.axisPoints);

        if (!data["bindings"].isEmpty) {
            foreach(Asdf child; data["bindings"].byElement) {
                
                // Skip empty children
                if (child["param_name"].isEmpty) continue;

                string paramName;
                child["param_name"].deserializeValue(paramName);

                if (paramName == "deform") {
                    auto binding = new DeformationParameterBinding(this);
                    binding.deserializeFromAsdf(child);
                    bindings ~= binding;
                } else {
                    auto binding = new ValueParameterBinding(this);
                    binding.deserializeFromAsdf(child);
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

    void update() {
        vec2 clamped = this.normalizedValue;

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

        vec2u index;
        vec2 offset;

        interpAxis(0, clamped.x, index.x, offset.x);
        if (isVec2) interpAxis(1, clamped.y, index.y, offset.y);

        foreach(binding; bindings) {
            binding.apply(index, offset);
        }
    }

    uint axisPointCount(uint axis = 0) {
        return cast(uint)axisPoints[axis].length;
    }

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
        Maps an input value to the internal range (0.0->1.0)
    */
    vec2 mapValue(vec2 value) {
        vec2 range = max - min;
        vec2 tmp = (value - min);
        vec2 off = vec2(tmp.x / range.x, tmp.y / range.y);

        vec2 clamped = vec2(
            clamp(off.x, 0, 1),
            clamp(off.y, 0, 1),
        );
        if (off != clamped) {
            debug writefln("Clamped parameter offset %s -> %s", off, clamped);
        }

        return clamped;
    }

    /**
        Maps an internal value (0.0->1.0) to the input range
    */
    vec2 unmapValue(vec2 value) {
        vec2 range = max - min;
        return vec2(range.x * value.x, range.y * value.y) + min;
    }

    /**
        Maps an input value to the internal range (0.0->1.0) for an axis
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
    float unmapAxis(uint axis, float value) {
        vec2 input = min;
        if (axis == 0) input.x = value;
        else input.y = value;
        vec2 output = unmapValue(input);
        if (axis == 0) return output.x;
        else return output.y;
    }

    /**
        Gets the breakpoint closests to the cursor
    */
    vec2u getClosestBreakpoint() {

        vec2u closestAxis;
        vec2 adjValue = normalizedValue();
        vec2 closestPoint = normalizedValue();
        float closestDist = float.infinity;
        foreach(xIdx; 0..axisPoints[0].length) {
            foreach(yIdx; 0..axisPoints[1].length) {
                vec2 pos = vec2(
                    axisPoints[0][xIdx],
                    axisPoints[1][yIdx]
                );

                float dist = adjValue.distance(pos);
                if (dist < closestDist) {
                    closestDist = dist;
                    closestPoint = pos;
                    closestAxis = vec2u(cast(uint)xIdx, cast(uint)yIdx);
                }
            }
        }

        return closestAxis;
    }

    /**
        Gets the breakpoint closests to the cursor
    */
    vec2 getClosestBreakpointLocation() {

        vec2 closestPoint = value;
        float closestDist = float.infinity;
        foreach(xIdx; 0..axisPoints[0].length) {
            foreach(yIdx; 0..axisPoints[1].length) {
                vec2 pos = vec2(
                    (max.x - min.x) * axisPoints[0][xIdx] + min.x,
                    (max.y - min.y) * axisPoints[1][yIdx] + min.y
                );

                float dist = value.distance(pos);
                if (dist < closestDist) {
                    closestDist = dist;
                    closestPoint = pos;
                }
            }
        }

        return closestPoint;
    }

    ParameterBinding getBinding(Node n, string bindingName) {
        foreach(ref binding; bindings) {
            if (binding.getNode() != n) continue;
            if (binding.getName == bindingName) return binding;
        }
        return null;
    }

    bool hasBinding(Node n, string bindingName) {
        foreach(ref binding; bindings) {
            if (binding.getNode() != n) continue;
            if (binding.getName == bindingName) return true;
        }
        return false;
    }

    ParameterBinding createBinding(Node n, string bindingName) {
        if (bindingName == "deform") {
            return new DeformationParameterBinding(this, n, bindingName);
        } else {
            return new ValueParameterBinding(this, n, bindingName);
        }
    }

    ParameterBinding getOrAddBinding(Node n, string bindingName) {
        ParameterBinding binding = getBinding(n, bindingName);
        if (binding is null) {
            binding = createBinding(n, bindingName);
            addBinding(binding);
        }
        return binding;
    }

    void addBinding(ParameterBinding binding) {
        assert(!hasBinding(binding.getNode, binding.getName));
        bindings ~= binding;
    }

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