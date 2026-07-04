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
import inochi2d.core.serde;

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
ParameterBinding tryDeserializeBinding(ref DataNode object, ref ModelState state, Parameter param) @nogc {
    if (state.doUpgrade08) {
        if (auto prop = object.tryGet!string(state, "param_name", null)) {
            state.info(nstring("0.8->0.9: upgrading binding ", prop, "..."));
            auto binding = prop == "deform" ?
                nogc_new!ParameterDeformBinding(param) :
                nogc_new!ParameterPropertyBinding(param);

            binding.deserialize(object, state);
            return cast(ParameterBinding)binding;
        }

        state.warning(nstring("0.8->0.9: Encountered a unnamed binding, ignoring..."));
        return null;
    }

    if (auto binding = in_binding_registry.tryCreateFrom(object, param)) {
        binding.deserialize(object, state);
        return binding;
    }

    state.warning(nstring("Encountered untyped binding, ignoring..."));
    return null;
}

/**
    Parameter binding base class.
*/
abstract
class ParameterBinding : NuRefCounted, ISerializable, IDeserializable!ModelState {
protected:
@nogc:

    /**
        Serializes this binding.
    */
    override void onSerialize(ref DataNode object) { }

    /**
        Deserialize this binding.
    */
    override void onDeserialize(ref DataNode object, ref ModelState state) { }

    /**
        Finalizes the parameter binding.

        Params:
            param = The parent parameter
            state = The state of the deserializer.
    */
    void onFinalize(Parameter param, ref ModelState state) { }

public:

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
        this.target = BindingTarget(null, null);
    }

    /**
        Construct a binding from its parameter, target node & target property.

        Params:
            parameter = The parameter this binding will belong to.
            node = The node being affected by this binding.
            prop = The target node property being affected by this binding.
    */
    this(Parameter parameter, Node node, string prop) {
        this.parameter = parameter;
        this.nodeId = node.guid;
        this.target = BindingTarget(node, prop);
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

    /**
        Serializes this parameter.

        Params:
            object = The data node to deserialize.
    */
    final void serialize(ref DataNode object) {
        this.onSerialize(object);
    }

    /**
        Deserializes this parameter.

        Params:
            object =    The data node to deserialize.
            state =     The state of the deserializer.
    */
    final void deserialize(ref DataNode object, ref ModelState state) {
        this.onDeserialize(object, state);
    }

    /**
        Finalizes the parameter.

        Params:
            param = The parent parameter
            state = The state of the deserializer.
    */
    final void finalize(Parameter param, ref ModelState state) {
        this.onFinalize(param, state);
    }
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