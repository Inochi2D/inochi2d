/**
    Deformation Bindings

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)

    Authors:
        Luna Nielsen
        Mireille Arseneault
        Hoshino Lina
*/
module inochi2d.param.bindings.deform;
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
    Parameter binding to a deformation property.
*/
@TypeId("deform", IN_MAKE_TAG!(1, 0))
class ParameterDeformBinding : ParameterBindingImpl!Deformation {
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
mixin Register!(ParameterDeformBinding, in_binding_registry);