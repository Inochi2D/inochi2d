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

enum ParamMergeMode {

    /**
        Parameters are merged additively
    */
    @serdeFlexible
    @serdeKeys("Additive", "additive")
    Additive,

    /**
        Parameters are merged with a weighted average
    */
    @serdeFlexible
    @serdeKeys("Weighted", "weighted")
    Weighted,

    /**
        Parameters are merged multiplicatively
    */
    @serdeFlexible
    @serdeKeys("Multiplicative", "multiplicative")
    Multiplicative,

    /**
        Forces parameter to be given value
    */
    @serdeFlexible
    @serdeKeys("Forced", "forced")
    Forced,

    /**
        Merge mode is passthrough
    */
    @serdeFlexible
    @serdeKeys("Passthrough", "passthrough")
    Passthrough,
}

/**
    A parameter
*/
class Parameter {
private:
    struct Combinator {
        vec2[] ivalues;
        float[] iweights;
        int isum;

        void clear() {
            isum = 0;
        }

        void resize(int reqLength) {
            ivalues.length = reqLength;
            iweights.length = reqLength;
        }

        void add(vec2 value, float weight) {
            if (isum >= ivalues.length) resize(isum+8);

            ivalues[isum] = value;
            iweights[isum] = weight;
            isum++;
        }

        void add(int axis, float value, float weight) {
            if (isum >= ivalues.length) resize(isum+8);

            ivalues[isum] = vec2(axis == 0 ? value : 1, axis == 1 ? value : 1);
            iweights[isum] = weight;
            isum++;
        }
        
        vec2 csum() {
            vec2 val = vec2(0, 0);
            foreach(i; 0..isum) {
                val += ivalues[i];
            }
            return val;
        }

        vec2 avg() {
            if (isum == 0) return vec2(1, 1);

            vec2 val = vec2(0, 0);
            foreach(i; 0..isum) {
                val += ivalues[i]*iweights[i];
            }
            return val/isum;
        }
    }

    Combinator iadd;
    Combinator imul;
protected:
    void serializeSelf(ref InochiSerializer serializer) {
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
        serializer.putKey("defaults");
        defaults.serialize(serializer);
        serializer.putKey("axis_points");
        serializer.serializeValue(axisPoints);
        serializer.putKey("merge_mode");
        serializer.serializeValue(mergeMode);
        serializer.putKey("bindings");
        auto arrstate = serializer.arrayBegin();
            foreach(binding; bindings) {
                serializer.elemBegin();
                binding.serializeSelf(serializer);
            }
        serializer.arrayEnd(arrstate);
    }

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
    vec2 latestInternal = vec2(0);
    vec2 previousInternal = vec2(0);

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
        Clone this parameter
    */
    Parameter dup() {
        Parameter newParam = new Parameter(name ~ " (Copy)", isVec2);

        newParam.min = min;
        newParam.max = max;
        newParam.axisPoints = axisPoints.dup;

        foreach(binding; bindings) {
            ParameterBinding newBinding = newParam.createBinding(
                binding.getNode(),
                binding.getName(),
                false
            );
            newBinding.interpolateMode = binding.interpolateMode;
            foreach(x; 0..axisPointCount(0)) {
                foreach(y; 0..axisPointCount(1)) {
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
    void serialize(ref InochiSerializer serializer) {
        auto state = serializer.objectBegin;
        serializeSelf(serializer);
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
        if (!data["defaults"].isEmpty) defaults.deserialize(data["defaults"]);
        if (!data["merge_mode"].isEmpty) data["merge_mode"].deserializeValue(this.mergeMode);

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

    void reconstruct(Puppet puppet) {
        foreach(i, binding; bindings) {
            binding.reconstruct(puppet);
        }
    }

    /**
        Finalize loading of parameter
    */
    void finalize(Puppet puppet) {
        this.makeIndexable();
        this.value = defaults;

        ParameterBinding[] validBindingList;
        foreach(i, binding; bindings) {
            if (puppet.find!Node(binding.getNodeUUID())) {
                binding.finalize(puppet);
                validBindingList ~= binding;
            }
        }
        
        bindings = validBindingList;
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
        vec2 offset_;

        if (!active)
            return;

        previousInternal = latestInternal;
        latestInternal = (value + iadd.csum()) * imul.avg();

        findOffset(this.mapValue(latestInternal), index, offset_);
        foreach(binding; bindings) {
            binding.apply(index, offset_);
            if (binding.getTarget().node !is null) {
                if (valueChanged()) binding.getTarget().node.notifyChange(binding.getTarget().node);
            }
        }

        // Reset combinatorics
        iadd.clear();
        imul.clear();
    }

    bool valueChanged() {
        return latestInternal != previousInternal;
    }

    void pushIOffset(vec2 offset, ParamMergeMode mode = ParamMergeMode.Passthrough, float weight=1) {
        if (mode == ParamMergeMode.Passthrough) mode = mergeMode;
        switch(mode) {
            case ParamMergeMode.Forced:
                this.value = offset;
                break;
            case ParamMergeMode.Additive:
                iadd.add(offset, 1);
                break;
            case ParamMergeMode.Multiplicative:
                imul.add(offset, 1);
                break;
            case ParamMergeMode.Weighted:
                imul.add(offset, weight);
                break;
            default: break;
        }
    }

    void pushIOffsetAxis(int axis, float offset, ParamMergeMode mode = ParamMergeMode.Passthrough, float weight=1) {
        if (mode == ParamMergeMode.Passthrough) mode = mergeMode;
        switch(mode) {
            case ParamMergeMode.Forced:
                this.value.vector[axis] = offset;
                break;
            case ParamMergeMode.Additive:
                iadd.add(axis, offset, 1);
                break;
            case ParamMergeMode.Multiplicative:
                imul.add(axis, offset, 1);
                break;
            case ParamMergeMode.Weighted:
                imul.add(axis, offset, weight);
                break;
            default: break;
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
            debug writeln("after move ", this.axisPointCount(0));
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
        Check if any bindings exists for a given node
    */
    bool hasAnyBinding(Node n) {
        foreach(ref binding; bindings) {
            if (binding.getNode() == n) return true;
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

        if (setZero) {
            vec2u zeroIndex = findClosestKeypoint(vec2(0, 0));
            vec2 zero = getKeypointValue(zeroIndex);
            if (abs(zero.x) < 0.001 && abs(zero.y) < 0.001) b.reset(zeroIndex);
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

private {
    Parameter delegate(Fghj) createFunc;
}

Parameter inParameterCreate(Fghj data) {
    return createFunc(data);
}

void inParameterSetFactory(Parameter delegate(Fghj) createFunc_) {
    createFunc = createFunc_;
}