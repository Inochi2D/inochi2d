module inochi2d.core.param.binding;
import inochi2d.fmt.serialize;
import inochi2d.math.serialization;
import inochi2d.core;
import inochi2d.math;
import std.exception;
import std.array;
import std.algorithm.mutation;

/**
    A target to bind to
*/
struct BindTarget {
    /**
        The node to bind to
    */
    Node node;

    /**
        The parameter to bind
    */
    string paramName;
}

/**
    A binding to a parameter, of a given value type
*/
interface ParameterBinding {
    /**
        Finalize loading of parameter
    */
    void finalize(Puppet puppet);

    /**
        Apply a binding to the model at the given parameter value
    */
    void apply(vec2u leftKeypoint, vec2 offset);

    /**
        Update keypoint interpolation
    */
    void reInterpolate();

    /**
        Add a keypoint
    */
    void insertKeyPoint(uint dimension, uint index);

    /**
        Remove a keypoint
    */
    void deleteKeyPoint(uint dimension, uint index);
}

/**
    A binding to a parameter, of a given value type
*/
abstract class ParameterBindingImpl(T) : ParameterBinding {
private:
    /**
        Node reference (for deserialization)
    */
    uint nodeRef;

public:
    /**
        Parent Parameter owning this binding
    */
    Parameter parameter;

    /**
        Reference to what parameter we're binding to
    */
    BindTarget target;

    /**
        The value at each 2D keypoint
    */
    T[][] values;

    /**
        Whether the value at each 2D keypoint is user-set
    */
    bool[][] isSet;

    this(Parameter parameter) {
        this.parameter = parameter;
    }

    this(Parameter parameter, Node targetNode, string paramName) {
        this.parameter = parameter;
        this.target.node = targetNode;
        this.target.paramName = paramName;

        uint xCount = parameter.keypointCount(0);
        uint yCount = parameter.keypointCount(1);
        values.length = xCount;
        isSet.length = xCount;
        foreach(i; 0..xCount) {
            values[i].length = yCount;
            isSet[i].length = yCount;
        }
    }

    /**
        Serializes a binding
    */
    void serialize(S)(ref S serializer) {
        serializer.putKey("node");
        serializer.putValue(target.node.uuid);
        serializer.putKey("param_name");
        serializer.putValue(target.paramName);
        serializer.putKey("values");
        serializer.putValue(values);
        serializer.putKey("isSet");
        serializer.putValue(isSet);
    }

    /**
        Deserializes a binding
    */
    SerdeException deserializeFromAsdf(Asdf data) {
        data["node"].deserializeValue(this.nodeRef);
        data["param_name"].deserializeValue(this.target.paramName);
        data["values"].deserializeValue(this.values);
        data["isSet"].deserializeValue(this.isSet);

        uint xCount = parameter.keypointCount(0);
        uint yCount = parameter.keypointCount(1);

        enforce(this.values.length == xCount, "Mismatched X value count");
        foreach(i; this.values) {
            enforce(i.length == yCount, "Mismatched Y value count");
        }

        enforce(this.isSet.length == xCount, "Mismatched X isSet count");
        foreach(i; this.isSet) {
            enforce(i.length == yCount, "Mismatched Y isSet count");
        }

        return null;
    }

    /**
        Finalize loading of parameter
    */
    void finalize(Puppet puppet) {
        this.target.node = puppet.find(nodeRef);
    }

    /**
        Re-calculate interpolation
    */
    void reInterpolate() {
    }

    void apply(vec2u leftKeypoint, vec2 offset) {
        T p0, p1;

        if (parameter.isVec2) {
            T p00 = values[leftKeypoint.x][leftKeypoint.y];
            T p01 = values[leftKeypoint.x][leftKeypoint.y + 1];
            T p10 = values[leftKeypoint.x + 1][leftKeypoint.y];
            T p11 = values[leftKeypoint.x + 1][leftKeypoint.y + 1];
            p0 = p00.interp(p01, offset.y);
            p1 = p10.interp(p11, offset.y);
        } else {
            p0 = values[leftKeypoint.x][0];
            p1 = values[leftKeypoint.x + 1][0];
        }

        applyToTarget(p0.interp(p1, offset.x));
    }

    void insertKeyPoint(uint dimension, uint index) {
        assert(dimension == 0 || dimension == 1);

        if (dimension == 0) {
            uint yCount = parameter.keypointCount(1);

            values.insertInPlace(index, cast(T[])[]);
            values[index].length = yCount;
            isSet.insertInPlace(index, cast(bool[])[]);
            isSet[index].length = yCount;
        } else if (dimension == 1) {
            foreach(i; this.values) {
                i.insertInPlace(index, T.init);
            }
            foreach(i; this.isSet) {
                i.insertInPlace(index, false);
            }
        }

        reInterpolate();
    }

    void deleteKeyPoint(uint dimension, uint index) {
        assert(dimension == 0 || dimension == 1);

        if (dimension == 0) {
            values = values.remove(index);
            isSet = isSet.remove(index);
        } else if (dimension == 1) {
            foreach(i; 0..this.values.length) {
                values[i] = values[i].remove(index);
            }
            foreach(i; 0..this.isSet.length) {
                isSet[i] = isSet[i].remove(index);
            }
        }

        reInterpolate();
    }

    /**
        Apply parameter to target node
    */
    abstract void applyToTarget(T value);
}

class ValueParameterBinding : ParameterBindingImpl!float {
    this(Parameter parameter) {
        super(parameter);
    }

    this(Parameter parameter, Node targetNode, string paramName) {
        super(parameter, targetNode, paramName);
    }

    override
    void applyToTarget(float value) {
        target.node.setValue(target.paramName, value);
    }
}

class DeformationParameterBinding : ParameterBindingImpl!Deformation {
    this(Parameter parameter) {
        super(parameter);
    }

    this(Parameter parameter, Node targetNode, string paramName) {
        super(parameter, targetNode, paramName);
    }

    override
    void applyToTarget(Deformation value) {
        enforce(this.target.paramName == "deform");

        if (Drawable d = cast(Drawable)target.node) {
            d.deformStack.push(value);
        }
    }
}
