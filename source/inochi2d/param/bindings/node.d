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
module inochi2d.param.bindings.node;
import inochi2d.param.parameters;
import inochi2d.param.bindings;
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

///**
//    A parameter binding affecting a node.
//*/
//abstract
//class ParameterNodeBinding : ParameterBinding {
//private:
//@nogc:
//    GUID nodeId;
//    Node target_;

//protected:
//    vector2d!bool defined_;

//    /**
//        Serialize this binding.
//    */
//    override
//    void onSerialize(ref DataNode object) {
//        super.onSerialize(object);
//        object["target"] = target_.guid.toString()[];
//        object["defined"] = defined_.data.serialize();
//    }

//    /**
//        Deserialize this binding.
//    */
//    override
//    void onDeserialize(ref DataNode object, ref ModelState state) {
//        super.onDeserialize(object, state);
//        if (state.doUpgrade08) {
//            this.nodeId = object.tryGetGUID(state, "node", "target");
//            if ("isSet" in object) {
//                object["isSet"].deserialize08NestedArrays(
//                    defined_, 
//                    state,
//                    parameter.dimensions == 1 ?
//                        vec2u(1, parameter.elementCounts[0]) :
//                        vec2u(parameter.elementCounts[0], parameter.elementCounts[1])
//                );
//            }
//            return;
//        }

//        this.nodeId = object.tryGetGUID(state, "node", "target");
//        object.tryGetRef(state, defined_.data, "defined");
//    }

//    /**
//        Finalizes the parameter binding.

//        Params:
//            puppet =    The parent puppet
//            state =     The state of the deserializer.
//    */
//    override
//    void onFinalize(Puppet puppet, ref ModelState state) {
//        if (auto node = puppet.find!Node(nodeId)) {
//            this.target_ = node;
//        }
//    }

//public:

//    /**
//        The target of the binding.
//    */
//    @property inout(Node) target() inout => target_;
//    @property void target(Node value) {
//        if (this.target_)
//            this.target_.release();

//        this.target_ = value.retained;
//    }

//    /**
//        Construct a binding from its parameter.

//        Params:
//            param = The parameter this binding will belong to.
//    */
//    this(Parameter param) {
//        super(param);
//        this.defined_.resizeToParam(param);
//    }

//    /**
//        Construct a binding from its parameter, target node.

//        Params:
//            param   = The parameter this binding will belong to.
//            node    = The node being affected by this binding.
//    */
//    this(Parameter param, Node node) {
//        super(param);
//        this.defined_.resizeToParam(param);
//        this.target_ = node;
//    }
//}

///**
//    Template that implements core functionality.
//*/
//mixin template ParameterNodeBindingImpl(T) {

//    /**
//        Keypoint operation to insert a keypoint at the given position.
//    */
//    override
//    void insertKeypoint(ParameterAxis axis, uint index) {
//        final switch (axis) {
//            case ParameterAxis.rows:
//                this.values_.resize(values_.rows + 1, values_.columns);
//                this.defined_.resize(defined_.rows + 1, defined_.columns);
//                this.values_[index + 1 .. $, 0 .. $] = values_[index .. $ - 1, 0 .. $];
//                this.defined_[index + 1 .. $, 0 .. $] = defined_[index .. $ - 1, 0 .. $];
//                this.values_[index, 0 .. $] = T.init;
//                this.defined_[index, 0 .. $] = false;
//                break;

//            case ParameterAxis.columns:
//                this.values_.resize(values_.rows, values_.columns + 1);
//                this.defined_.resize(defined_.rows, defined_.columns + 1);
//                this.values_[0 .. $, index + 1 .. $] = values_[0 .. $, index .. $ - 1];
//                this.defined_[0 .. $, index + 1 .. $] = defined_[0 .. $, index .. $ - 1];
//                this.values_[0 .. $, index] = T.init;
//                this.defined_[0 .. $, index] = false;
//                break;
//        }

//        fillBlanks();
//    }

//    /**
//        Keypoint operation to move a keypoint to the given position.
//    */
//    override
//    void moveKeypoint(ParameterAxis axis, uint index, uint dest) {
//        assert(false, "not implemented");

//        final switch (axis) {
//            case ParameterAxis.rows:
//                break;

//            case ParameterAxis.columns:
//                break;
//        }

//        fillBlanks();
//    }

//    /**
//        Keypoint operation to delete the keypoint at the given position.
//    */
//    override
//    void deleteKeypoint(ParameterAxis axis, uint index) {
//        assert(false, "not implemented");

//        final switch (axis) {
//            case ParameterAxis.rows:
//                break;

//            case ParameterAxis.columns:
//                break;
//        }

//        fillBlanks();
//    }

//    /**
//        Keypoint operation to scale a keypoint by a given factor.
//    */
//    override
//    void scaleKeypoint(ParameterAxis axis, uint index, float scale) {
//        assert(false, "not implemented");
//    }

//    /**
//        Keypoint operation to copy its value to another binding's keypoint.
//    */
//    override
//    void copyKeypoint(vec2u index, ParameterBinding other, vec2u dest) {
//        assert(false, "not implemented");
//    }

//    /**
//        Clear all keypoint values.
//    */
//    override
//    void clear() {
//        this.defined_[] = false;
//        for (uint y = 0; y < values.rows; ++y) {
//            for (uint x = 0; x < values.columns; ++x) {
//                this.reset(vec2u(y, x));
//            }
//        }
//    }
//}
