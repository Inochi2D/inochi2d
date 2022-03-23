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
        vec2 range = max - min;
        vec2 tmp = (value - min);
        vec2 off = vec2(tmp.x / range.x, tmp.y / range.y);

        vec2 clamped = off.clamp(vec2(0, 0), vec2(1, ));
        if (off != clamped) {
            debug writefln("Clamped parameter offset %s -> %s", off, clamped);
        }

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
        axisPoints[axis].remove(index);

        // Tell all bindings to remove it from their arrays
        foreach(binding; bindings) {
            binding.deleteKeypoints(axis, index);
        }
    }

    void makeIndexable() {
        import std.uni : toLower;
        indexableName = name.toLower;
    }
}