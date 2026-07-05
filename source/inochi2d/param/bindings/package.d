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
import inochi2d.param.parameters;
import inochi2d.param.utils;
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

public import inochi2d.param.bindings.node;
public import inochi2d.param.bindings.deform;
public import inochi2d.param.bindings.property;

/**
    The public parameter binding registry.
*/
__gshared TypeRegistry!(ParameterBinding, Parameter) in_binding_registry;

/**
    Deserialize a parameter binding depending on its shape.

    If the property name is "deform", assume it is a deformation binding.
        Otherwise, assume it is a numeric value binding.
*/
ParameterBinding tryDeserializeBinding(ref DataNode object, ref ModelState state, Parameter param) @nogc {
    //if (state.doUpgrade08) {
    //    if (auto prop = object.tryGet!string(state, "param_name", null)) {
    //        state.info(nstring("0.8->0.9: upgrading binding ", prop, "..."));
    //        auto binding = prop == "deform" ?
    //            nogc_new!ParameterDeformBinding(param) :
    //            nogc_new!ParameterPropertyBinding(param);

    //        binding.deserialize(object, state);
    //        return cast(ParameterBinding)binding;
    //    }

    //    state.warning(nstring("0.8->0.9: Encountered a unnamed binding, ignoring..."));
    //    return null;
    //}

    //if (auto binding = in_binding_registry.tryCreateFrom(object, param)) {
    //    binding.deserialize(object, state);
    //    return binding;
    //}

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
    Parameter parameter;
    InterpolateMode interpMode = InterpolateMode.linear;

    /**
        Serializes this binding.
    */
    override void onSerialize(ref DataNode object) {
        object["interpolate_mode"] = cast(uint)interpMode;
    }

    /**
        Deserialize this binding.
    */
    override void onDeserialize(ref DataNode object, ref ModelState state) {
        if (auto mode = "interpolate_mode" in object) {
            if (mode.isNumber) {
                interpMode = cast(InterpolateMode)((*mode).tryGet!uint(state));
            } else {
                interpMode = (*mode).tryGet!string(state).toInterpolateMode();
            }
        }
    }

    /**
        Finalizes the parameter binding.

        Params:
            puppet =    The parent puppet
            state =     The state of the deserializer.
    */
    void onFinalize(Puppet puppet, ref ModelState state) {
    }

public:

    /**
        Construct a binding from its parameter.

        Params:
            param = The parameter this binding will belong to.
    */
    this(Parameter param) {
        this.parameter = param;
    }

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
        Finalizes the parameter binding.

        Params:
            puppet =    The parent puppet
            state =     The state of the deserializer.
    */
    final void finalize(Puppet puppet, ref ModelState state) {
        this.onFinalize(puppet, state);
    }
}
