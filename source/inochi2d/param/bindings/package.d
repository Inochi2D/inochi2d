/**
    Bridge parameter values to mesh deformations and more.

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)

    Authors:
        Luna Nielsen
        Mireille Arseneault
        Hoshino Lina
*/
module inochi2d.param.bindings;
import inochi2d.param.parameter;
import inochi2d.param.binding;
import inochi2d.core.registry;
import inochi2d.core.vector2d;
import inochi2d.core.serde;
import inochi2d.core.math;
import inochi2d.core.guid;
import inochi2d.common;
import inochi2d.puppet;
import inochi2d.nodes;
import nulib;
import numem;

public import inochi2d.param.bindings.deform;
public import inochi2d.param.bindings.property;

/**
    The public parameter binding registry.
*/
__gshared TypeRegistry!(ParameterBinding, Parameter) in_binding_registry;

/**
    Parameter binding to a property of a given type.
*/
abstract
class ParameterBindingImpl(T) : ParameterBinding {
protected:
@nogc:

    /**
        Serialize this binding.
    */
    override
    void onSerialize(ref DataNode object) {
        object["node"] = target.node.guid.toString()[];
        object["param_name"] = target.prop;
        object["values"] = values.data.serialize();
        object["defined"] = defined.data.serialize();
        object["interpolate_mode"] = cast(uint)interpMode;
    }

    /**
        Deserialize this binding.
    */
    override
    void onDeserialize(ref DataNode object, ref ModelState state) {
        nodeId = object.tryGetGUID(state, "node", "target");
        object.tryGetRef(state, target.prop, "param_name");
        // object.tryGetRef(values, "values");
        // object.tryGetRef(isSet_, "isSet");

        if (auto mode = "interpolate_mode" in object) {
            if (mode.isNumber) {
                interpMode = cast(InterpolateMode)((*mode).tryGet!uint(state));
            } else {
                interpMode = (*mode).tryGet!string(state).toInterpolateMode();
            }
        }
    }

public:
    vector2d!T values;
    vector2d!bool defined;

    /**
        Construct a binding from its parameter.

        Params:
            parameter = The parameter this binding will belong to.
    */
    this(Parameter parameter) {
        super(parameter);

        if (parameter.dimensions == 1) {
            values.resize(1, parameter.elementCounts[0]);
            defined.resize(1, parameter.elementCounts[0]);
        } else if (parameter.dimensions == 2) {
            values.resize(parameter.elementCounts[0], parameter.elementCounts[1]);
            defined.resize(parameter.elementCounts[0], parameter.elementCounts[1]);
        }
    }

    /**
        Construct a binding from its parameter, target node & target property.

        Params:
            parameter   = The parameter this binding will belong to.
            node        = The node being affected by this binding.
            prop        = The target node property being affected by this binding.
    */
    this(Parameter parameter, Node node, string prop) {
        super(parameter, node, prop);
        if (parameter.dimensions == 1) {
            values.resize(1, parameter.elementCounts[0]);
            defined.resize(1, parameter.elementCounts[0]);
        } else if (parameter.dimensions == 2) {
            values.resize(parameter.elementCounts[0], parameter.elementCounts[1]);
            defined.resize(parameter.elementCounts[0], parameter.elementCounts[1]);
        }
    }

    /**
        Find the interpolated value of the keypoints at the given index.

        Params:
            index   = The index of the first keypoint to use.
            norm    = Normalized scalar used to interpolate values.

        Returns:
            The interpolation of a keypoint and its neighbors.
    */
    T getInterpolatedKeypoint(vec2u index, vec2 norm) const {
        final switch (interpMode) {
            case InterpolateMode.nearest:
                return getInterpolatedKeypoint_nearest(index, norm);

            case InterpolateMode.linear:
                return getInterpolatedKeypoint_linear(index, norm);

            case InterpolateMode.stepped:
                return getInterpolatedKeypoint_stepped(index, norm);

            case InterpolateMode.quadratic:
                return getInterpolatedKeypoint_quadratic(index, norm);

            case InterpolateMode.cubic:
                return getInterpolatedKeypoint_cubic(index, norm);
        }
    }

    private T getInterpolatedKeypoint_nearest(vec2u index, vec2 norm) const {
        assert(false, "not implemented");
    }

    private T getInterpolatedKeypoint_linear(vec2u index, vec2 norm) const {
        assert(false, "not implemented");
    }

    private T getInterpolatedKeypoint_stepped(vec2u index, vec2 norm) const {
        assert(false, "not implemented");
    }

    private T getInterpolatedKeypoint_quadratic(vec2u index, vec2 norm) const {
        assert(false, "not implemented");
    }

    private T getInterpolatedKeypoint_cubic(vec2u index, vec2 norm) const {
        assert(false, "not implemented");
    }

    /**
        Bind to a puppet.
    */
    override
    void bind(Puppet puppet) {
        target.node = puppet.find(nodeId);
    }

    /**
        Apply the given interpolated keypoint to this binding.

        Params:
            index = The index of the first keypoint in our quartet.
            norm = The normalized position in our keypoint quartet.
    */
    override
    void apply(vec2u index, vec2 norm) {
        apply(getInterpolatedKeypoint(index, norm));
    }

    /**
        Keypoint operation to insert a keypoint at the given position.
    */
    override
    void insertKeypoint(ParameterAxis axis, uint index) {
        final switch (axis) {
            case ParameterAxis.rows:
                values.resize(values.rows + 1, values.columns);
                defined.resize(defined.rows + 1, defined.columns);
                values[index + 1 .. $, 0 .. $] = values[index .. $ - 1, 0 .. $];
                defined[index + 1 .. $, 0 .. $] = defined[index .. $ - 1, 0 .. $];
                values[index, 0 .. $] = T.init;
                defined[index, 0 .. $] = false;
                break;

            case ParameterAxis.columns:
                values.resize(values.rows, values.columns + 1);
                defined.resize(defined.rows, defined.columns + 1);
                values[0 .. $, index + 1 .. $] = values[0 .. $, index .. $ - 1];
                defined[0 .. $, index + 1 .. $] = defined[0 .. $, index .. $ - 1];
                values[0 .. $, index] = T.init;
                defined[0 .. $, index] = false;
                break;
        }

        fillBlanks();
    }

    /**
        Keypoint operation to move a keypoint to the given position.
    */
    override
    void moveKeypoint(ParameterAxis axis, uint index, uint dest) {
        assert(false, "not implemented");

        final switch (axis) {
            case ParameterAxis.rows:
                break;

            case ParameterAxis.columns:
                break;
        }

        fillBlanks();
    }

    /**
        Keypoint operation to delete the keypoint at the given position.
    */
    override
    void deleteKeypoint(ParameterAxis axis, uint index) {
        assert(false, "not implemented");

        final switch (axis) {
            case ParameterAxis.rows:
                break;

            case ParameterAxis.columns:
                break;
        }

        fillBlanks();
    }

    /**
        Keypoint operation to scale a keypoint by a given factor.
    */
    override
    void scaleKeypoint(ParameterAxis axis, uint index, float scale) {
        assert(false, "not implemented");
    }

    /**
        Keypoint operation to copy its value to another binding's keypoint.
    */
    override
    void copyKeypoint(vec2u index, ParameterBinding other, vec2u dest) {
        assert(false, "not implemented");
    }

    /**
        Clear all keypoint values.
    */
    override
    void clear() {
        defined[] = false;
        for (uint y = 0; y < values.rows; ++y) {
            for (uint x = 0; x < values.columns; ++x) {
                reset(values[y, x]);
            }
        }
    }

    /**
        Initialize the keypoint at the given index with its current value.
    */
    override
    void enable(vec2u index) {
        defined[index.y, index.x] = true;
        fillBlanks();
    }

    /**
        Reinitialize the keypoint at the given index to its default value.
    */
    override
    void reset(vec2u index) {
        reset(values[index.y, index.x]);
        defined[index.y, index.x] = true;
        fillBlanks();
    }

    /**
        Clear the keypoint at the given index to its default value.
    */
    override
    void disable(vec2u index) {
        reset(values[index.y, index.x]);
        defined[index.y, index.x] = false;
        fillBlanks();
    }

    /**
        Fill undefined keypoints with sensible defaults.
    */
    override
    void fillBlanks() {
        assert(false, "not implemented");
    }

    /**
        Check whether the keypoint at the given index is defined.
    */
    override
    bool isDefined(uint index) const {
        return defined[0, index];
    }

    /**
        Apply the given value to this binding's target.
    */
    abstract
    void apply(T value);

    /**
        Reset the given keypoint value.
    */
    abstract
    void reset(ref T value) const;
}