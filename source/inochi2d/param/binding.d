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
module inochi2d.param.binding;
import inochi2d.param.parameter;
import inochi2d.common;
import inochi2d.puppet;
import inochi2d.nodes;
import inochi2d.core;

import numem;
import numem.core.memory;

import nulib.collections;
import nulib.string;

public import inochi2d.param.bindings;

/**
    Deserialize a parameter binding depending on its shape.

    If the property name is "deform", assume it is a deformation binding.
        Otherwise, assume it is a numeric value binding.
*/
ParameterBinding tryGetBinding(ref DataNode object, ref ModelState state, Parameter param) @nogc {
    if (auto prop = object.tryGet!string(state, "prop", null)) {
        if (prop == "deform") {
            auto binding = nogc_new!ParameterDeformBinding(param);
            object.deserialize(state, binding);
            return cast(ParameterBinding)binding;
        } else {
            auto binding = nogc_new!ParameterPropertyBinding(param);
            object.deserialize(state, binding);
            return cast(ParameterBinding)binding;
        }
    }

    return null;
}

/**
    Parameter binding base class.
*/
abstract
class ParameterBinding : NuRefCounted, ISerializable, IDeserializable!ModelState {
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