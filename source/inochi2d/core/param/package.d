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
        Position of the keypoints in two dimensions
    */
    float[][2] keypointPos = [[0, 1], [0]];

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
    this(string name) {
        this.uuid = inCreateUUID();
        this.name = name;
    }

    /**
        Serializes a parameter
    */
    void serialize(S)(ref S serializer) {
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
        serializer.putKey("keypoint_pos");
        serializer.serializeValue(keypointPos);
        serializer.putKey("bindings");
        serializer.serializeValue(bindings);
    }

    /**
        Deserializes a parameter
    */
    SerdeException deserializeFromAsdf(Asdf data) {
        data["uuid"].deserializeValue(this.uuid);
        data["name"].deserializeValue(this.name);
        data["is_vec2"].deserializeValue(this.isVec2);
        min.deserialize(data["min"]);
        max.deserialize(data["max"]);
        data["keypoint_pos"].deserializeValue(this.keypointPos);

        foreach(child; data["bindings"].byElement) {
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

        return null;
    }

    /**
        Finalize loading of parameter
    */
    void finalize(Puppet puppet) {
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

        void interpAxis(uint dimension, float val, out uint index, out float offset) {
            float[] pos = keypointPos[dimension];

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

    uint keypointCount(uint dimension = 0) {
        return cast(uint)keypointPos[dimension].length;
    }

}