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
import inochi2d.param.parameter;
import inochi2d.param.bindings;
import inochi2d.core.registry;
import inochi2d.core.serde;
import inochi2d.core.math;
import inochi2d.core.guid;
import inochi2d.common;
import inochi2d.puppet;
import inochi2d.nodes;
import nulib;
import numem;

/**
    Parameter binding to a single numeric property.
*/
@TypeId("property", IN_MAKE_TAG!(0, 0))
class ParameterPropertyBinding : ParameterBindingImpl!float {
protected:
@nogc:

    /**
        Serialize this parameter binding.
    */
    override
    void onSerialize(ref DataNode object) {

    }
    
    /**
        Deserialize this parameter.
    */
    override
    void onDeserialize(ref DataNode object, ref ModelState state) {
        
    }

public:

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
mixin Register!(ParameterPropertyBinding, in_binding_registry);