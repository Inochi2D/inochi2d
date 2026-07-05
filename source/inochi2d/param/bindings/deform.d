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
//    Parameter binding to a deformation property.
//*/
//@TypeId("deform", IN_MAKE_TAG!(1, 0))
//class ParameterDeformBinding : ParameterNodeBinding {
//private:
//@nogc:
//    vector2d!Deformation values_;

//protected:

//    /**
//        Serialize this parameter binding.
//    */
//    override
//    void onSerialize(ref DataNode object) {
//        super.onSerialize(object);

//    }

//    /**
//        Deserialize this parameter.
//    */
//    override
//    void onDeserialize(ref DataNode object, ref ModelState state) {
//        super.onDeserialize(object, state);
//        if (state.doUpgrade08) {
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

//    }

//public:

//    /**
//        The values of the binding.
//    */
//    @property slice2d!Deformation values() => values_[];

//    /**
//        Construct a deformation binding without a target.

//        Params:
//            parameter = The owner/parent of this binding.
//    */
//    this(Parameter param) {
//        super(param);
//        values_.resizeToParam(param);
//    }

//    /**
//        Construct a deformation binding.

//        Params:
//            param   = The owner/parent of this binding.
//            node    = The node affected by this binding.
//    */
//    this(Parameter param, Node node) {
//        super(param, node);
//        this.values_.resizeToParam(param);
//    }

//    /**
//        Apply the given interpolated keypoint to this binding.

//        Params:
//            index = The index of the first keypoint in our quartet.
//            norm = The normalized position in our keypoint quartet.
//    */
//    override
//    void apply(vec2u index, vec2 norm) {
//        apply(getInterpolatedKeypoint(index, norm));
//        if (auto deform = cast(IDeformable)target) {
//            deform.deform(value.vertexOffsets, false);
//        }
//    }

//    /**
//        Fill undefined keypoints with sensible defaults.
//    */
//    override void fillBlanks() { }

//    /**
//        Check whether the keypoint at the given index is defined.
//    */
//    override
//    bool isDefined(uint index) const {
//        return defined_[0, index];
//    }

//    /**
//        Check whether this binding is compatible with the given node.
//    */
//    override
//    bool isCompatibleWith(Node other) const {
//        if (auto a = cast(IDeformable)target) {
//            if (auto b = cast(IDeformable)other) {
//                return a.deformPoints.length == b.deformPoints.length;
//            }
//        }

//        return false;
//    }

//    /**
//        Reinitialize the keypoint at the given index to its default value.
//    */
//    override
//    void reset(vec2u index) {
//        auto deform = cast(IDeformable)target;
//        this.values_[index.y, index.x].clear(deform.deformPoints.length);
//        this.defined_[index.y, index.x] = true;
//    }

//    /**
//        Initialize the keypoint at the given index with its current value.
//    */
//    override
//    void enable(vec2u index) {
//        this.defined_[index.y, index.x] = true;
//        fillBlanks();
//    }

//    /**
//        Clear the keypoint at the given index to its default value.
//    */
//    override
//    void disable(vec2u index) {
//        this.values_[index.y, index.x] = T.init;
//        this.defined_[index.y, index.x] = false;
//        fillBlanks();
//    }

//    // Add general implementation
//    mixin ParameterNodeBindingImpl!Deformation;
//}
//mixin Register!(ParameterDeformBinding, in_binding_registry);
