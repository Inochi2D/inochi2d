/**
    Inochi2D Bone Modifiers

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.nodes.bone.modifier;
import inochi2d.nodes;

/**
    A modifier that affect one given bone and potentially any
    child bones in the skeleton chain.
*/
@TypeIdAbstract
@TypeId("BoneModifier", IN_MAKE_TAG!(0, 4))
abstract class BoneModifier : Node {

}
mixin Register!(BoneModifier, in_node_registry);