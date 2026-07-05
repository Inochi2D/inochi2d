/**
    Inochi2D Animated Part Node

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.nodes.visual.animatedpart;
import inochi2d.nodes.visual.part;
import inochi2d.common;
import inochi2d.nodes;
import inochi2d.core;

/**
    Parts which contain spritesheet animation
*/
@TypeId("AnimatedPart", IN_MAKE_TAG!(2, 1))
class AnimatedPart : Part {
private:
@nogc:
    vec2 frameSize_;
    vec2u frameCount_;
    vec2u frame_;

protected:

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
    */
    override
    void onSerialize(ref DataNode object) {
        super.onSerialize(object);

        object["frameSize"] = frameSize_.serialize();
        object["frameCount"] = frameCount_.serialize();
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object =    The DataNode to deserialize from.
            state =     The state of the deserializer.
    */
    override
    void onDeserialize(ref DataNode object, ref ModelState state) {
        super.onDeserialize(object, state);

        object.tryGetRef(state, frameSize_, "frameSize");
        object.tryGetRef(state, frameCount_, "frameCount");
    }

    /**
        Called during the late update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onPostUpdate(DrawList drawList) {
        this.deformedMesh.applyUVOffset(vec2(
            frameSize_.x * cast(float)frame_.x,
            frameSize_.y * cast(float)frame_.y,
        ));
        super.onPostUpdate(drawList);
    }

public:
    
    /**
        The size of a single frame in texel coordinates.
    */
    @property ref vec2 frameSize() => frameSize_;

    /**
        The amount of frames and animations in the animated part.
    */
    @property ref vec2u frameCount() => frameCount_;
}

mixin Register!(AnimatedPart, in_node_registry);
