/**
    Property bindings

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)

    Authors:
        Luna Nielsen
        Mireille Arseneault
        Hoshino Lina
*/
module inochi2d.param.bindings.property;
import inochi2d.param.parameters;
import inochi2d.param.bindings;
import inochi2d.param.utils;
import inochi2d.core.vector2d;
import inochi2d.core.registry;
import inochi2d.core.serde;
import inochi2d.core.math;
import inochi2d.core.guid;
import inochi2d.common;
import inochi2d.puppet;
import inochi2d.nodes;
import nulib;
import numem;

///**
//    Parameter binding to a single numeric property.
//*/
//@TypeId("property", IN_MAKE_TAG!(0, 0))
//class ParameterPropertyBinding : ParameterNodeBinding {
//private:
//@nogc:
//    vector2d!float values_;
//    nstring prop_;

//protected:

//    /**
//        Serialize this parameter binding.
//    */
//    override
//    void onSerialize(ref DataNode object) {
//        super.onSerialize(object);
//        object["values"] = values.data.serialize();
//    }
    
//    /**
//        Deserialize this parameter.
//    */
//    override
//    void onDeserialize(ref DataNode object, ref ModelState state) {
//        super.onDeserialize(object, state);
//        if (state.doUpgrade08) {
//            object.tryGetRef(state, prop_, "param_name");
//            if ("values" in object) {
//                object["values"].deserialize08NestedArrays(
//                    values_, 
//                    state,
//                    parameter.dimensions == 1 ?
//                        vec2u(1, parameter.elementCounts[0]) :
//                        vec2u(parameter.elementCounts[0], parameter.elementCounts[1])
//                );
//            }
//            return;
//        }

//        object.tryGetRef(state, prop_, "property");
//        object.tryGetRef(state, prop_, "property");
//    }

//public:

//    /**
//        The values of the binding.
//    */
//    @property slice2d!float values() => values_[];

//    /**
//        The property that the binding applies to.
//    */
//    @property string property() => prop_[];
//    @property void property(string value) {
//        this.prop_ = value;
//    }

//    /**
//        Construct a binding from its parameter.

//        Params:
//            param = The parameter this binding will belong to.
//    */
//    this(Parameter param) {
//        super(param);
//        this.values_.resizeToParam(param);
//    }

//    /**
//        Construct a binding from its parameter, target node & target property.

//        Params:
//            param   = The parameter this binding will belong to.
//            node    = The node being affected by this binding.
//            prop    = The target node property being affected by this binding.
//    */
//    this(Parameter param, Node node, string prop) {
//        super(parameter, node);
//        this.values_.resizeToParam(param);
//        this.prop_ = prop;
//    }

//    /**
//        Check whether this binding is compatible with the given node.
//    */
//    override
//    bool isCompatibleWith(Node other) const {
//        return other.hasProperty(prop_);
//    }

//    /**
//        Apply the given value to this binding's target.
//    */
//    void apply(float value) {
//        target.setProperty(prop_, value);
//    }

//    /**
//        Reset keypoint to default based on node property.
//    */
//    void reset(ref float value) const {
//        value = target.getPropertyDefault(prop_);
//    }

//    // Add general implementation
//    mixin ParameterNodeBindingImpl!float;
//}
//mixin Register!(ParameterPropertyBinding, in_binding_registry);