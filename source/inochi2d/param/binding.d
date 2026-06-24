/**
    Bridge parameter values to mesh deformations and more.

    Copyright © 2026, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors:
    - Luna Nielsen
    - Mireille Arseneault
    - Hoshino Lina
*/
module inochi2d.param.binding;
import inochi2d.param.parameter;
import inochi2d.puppet;
import inochi2d.nodes;
import inochi2d.core;

import numem;
import numem.core.memory;

import nulib.collections;
import nulib.string;

/**
    Indicates which of a node's properties is affected by a given binding.
*/
struct BindingTarget {
    /**
        Node affected by a given binding.
    */
    Node node;

    /**
        Which of our node's properties is affected by a given binding.
    */
    string prop;
}

/**
    Parameter binding base class.
*/
abstract
class ParameterBinding : NuRefCounted, ISerializable, IDeserializable {
public:
@nogc:
    GUID nodeId;

    Parameter parameter;

    BindingTarget target;

    InterpolateMode interpMode = InterpolateMode.linear;

    /**
        Construct a binding from its parameter.

        Params:
            parameter = The parameter this binding will belong to.
    */
    this(Parameter parameter) {
        this.parameter = parameter;
        target = BindingTarget(null, null);
    }

    /**
        Construct a binding from its parameter, target node & target property.

        Params:
            parameter = The parameter this binding will belong to.
            node = The node being affected by this binding.
            prop = The target node property being affected by this binding.
    */
    this(Parameter parameter, Node node, string prop) {
        nodeId = node.guid;
        this.parameter = parameter;
        target = BindingTarget(node, prop);
    }

    /**
        Bind this binding to the given puppet.
    */
    abstract
    void bind(Puppet puppet);

    /**
        Apply the given interpolated keypoint to this binding.

        Params:
            index = The index of the first keypoint in our quartet.
            norm = The normalized position in our keypoint quartet.
    */
    abstract
    void apply(vec2u index, vec2 norm);


    /**
        Keypoint operation to insert a keypoint at the given position.
    */
    abstract
    void insertKeypoint(ParameterAxis axis, uint index);

    /**
        Keypoint operation to move a keypoint to the given position.
    */
    abstract
    void moveKeypoint(ParameterAxis axis, uint index, uint dest);

    /**
        Keypoint operation to delete the keypoint at the given position.
    */
    abstract
    void deleteKeypoint(ParameterAxis axis, uint index);


    /**
        Keypoint operation to scale a keypoint by a given factor.
    */
    abstract
    void scaleKeypoint(ParameterAxis axis, uint index, float scale);

    /**
        Keypoint operation to copy its value to another binding's keypoint.
    */
    abstract
    void copyKeypoint(vec2u index, ParameterBinding other, vec2u dest);


    /**
        Clear all keypoint values.
    */
    abstract
    void clear();

    /**
        Initialize the keypoint at the given index with its interpolated value.
    */
    abstract
    void enable(vec2u index);

    /**
        Reinitialize the keypoint at the given index to its default value.
    */
    abstract
    void reset(vec2u index);

    /**
        Clear the keypoint at the given index to its default value.
    */
    abstract
    void disable(vec2u index);


    /**
        Fill undefined keypoints with sensible defaults.
    */
    abstract
    void fillBlanks();


    /**
        Check whether the keypoint at the given index is defined.
    */
    abstract
    bool isDefined(uint index) const;

    /**
        Check whether this binding is compatible with the given node.
    */
    abstract
    bool isCompatibleWith(Node other) const;
}

/**
    Parameter binding to a property of a given type.
*/
abstract
class ParameterBindingImpl(T) : ParameterBinding {
public:
@nogc:
    vector2d!T values;

    vector2d!bool defined;

    /**
        Construct a binding from its parameter.

        Params:
            parameter = The parameter this binding will belong to.
    */
    this(Parameter parameter) {
        super(parameter);

        if (auto param1d = cast(Parameter1D)parameter) {
            values.resize(1, param1d.points.length);
            defined.resize(1, param1d.points.length);
        } else if (auto param2d = cast(Parameter2D)parameter) {
            values.resize(param2d.vpoints.length, param2d.hpoints.length);
            defined.resize(param2d.vpoints.length, param2d.hpoints.length);
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

        if (auto param1d = cast(Parameter1D)parameter) {
            values.resize(1, param1d.points.length);
            defined.resize(1, param1d.points.length);
        } else if (auto param2d = cast(Parameter2D)parameter) {
            values.resize(param2d.vpoints.length, param2d.hpoints.length);
            defined.resize(param2d.vpoints.length, param2d.hpoints.length);
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
        Serialize this binding.
    */
    override
    void onSerialize(ref DataNode object, bool recursive = true) {
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
    void onDeserialize(ref DataNode object) {
        nodeId = object.tryGetGUID("node", "target");
        object.tryGetRef(target.prop, "param_name");
        // object.tryGetRef(values, "values");
        // object.tryGetRef(isSet_, "isSet");

        if (auto mode = "interpolate_mode" in object) {
            if (mode.isNumber) {
                interpMode = cast(InterpolateMode)((*mode).tryGet!uint());
            } else {
                interpMode = (*mode).tryGet!string().toInterpolateMode();
            }
        }
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

/**
    Parameter binding to a single numeric property.
*/
class ParameterScalarBinding : ParameterBindingImpl!float {
public:
@nogc:
    this(Parameter parameter) {
        super(parameter);
    }

    this(Parameter parameter, Node node, string prop) {
        super(parameter, node, prop);
    }

    /**
        Apply the given value to this binding's target.
    */
    override
    void apply(float value) {
        target.node.setProperty(target.prop, value);
    }

    /**
        Reset keypoint to default based on node property.
    */
    override
    void reset(ref float value) const {
        value = target.node.getPropertyDefault(target.prop);
    }

    /**
        Check whether this binding is compatible with the given node.
    */
    override
    bool isCompatibleWith(Node other) const {
        return other.hasProperty(target.prop);
    }
}

/**
    Parameter binding to a deformation property.
*/
class ParameterDeformBinding : ParameterBindingImpl!Deformation {
public:
@nogc:
    /**
        Construct a deformation binding without a target.

        Params:
            parameter = The owner/parent of this binding.
    */
    this(Parameter parameter) {
        super(parameter);
    }

    /**
        Construct a deformation binding.

        Params:
            parameter   = The owner/parent of this binding.
            node        = The node affected by this binding.
            prop        = The property affected by this binding.
    */
    this(Parameter parameter, Node node, string prop) {
        super(parameter, node, prop);
    }

    /**
        Apply the given value to this binding's target.
    */
    override
    void apply(Deformation value) {
        if (auto deform = cast(IDeformable)target.node) {
            deform.deform(value.vertexOffsets, false);
        }
    }

    /**
        Reset deformation to identity, with the right vertex count.
    */
    override
    void reset(ref Deformation value) const {
        auto deform = cast(IDeformable)target.node;
        value.clear(deform.deformPoints.length);
    }

    /**
        Check whether this binding is compatible with the given node.
    */
    override
    bool isCompatibleWith(Node other) const {
        if (auto a = cast(IDeformable)target.node) {
            if (auto b = cast(IDeformable)other) {
                return a.deformPoints.length == b.deformPoints.length;
            }
        }

        return false;
    }
}

/**
    Deserialize a parameter binding depending on its shape.

    If the property name is "deform", assume it is a deformation binding.
        Otherwise, assume it is a numeric value binding.
*/
ParameterBinding tryGetBinding(ref DataNode object, Parameter param) @nogc {
    if (auto prop = object.tryGet!string("prop", null)) {
        if (prop == "deform") {
            auto binding = nogc_new!ParameterDeformBinding(param);
            object.deserialize(binding);
            return cast(ParameterBinding)binding;
        } else {
            auto binding = nogc_new!ParameterScalarBinding(param);
            object.deserialize(binding);
            return cast(ParameterBinding)binding;
        }
    }

    return null;
}