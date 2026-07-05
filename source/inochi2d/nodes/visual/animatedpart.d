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
        Called when the node is to define its properties.

        Call $(D propList.define) with a quark to do this.

        Params:
            propList = The property list to populate.
    */
    override
    void onDefineProperties(ref PropertyStore propList) {
        super.onDefineProperties(propList);

        propList.define!float(PROP_FRAME_X, 0);
        propList.define!float(PROP_FRAME_Y, 0);

        // Define combined overlays.
        propList.defineOverlay!vec3(PROP_FRAME_XY, propList.offsetOf(PROP_FRAME_X));
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

//
//          QUARKS
//

mixin RegisterQuarks!();

/**
    X frame index.
*/
@propkey("frame.xy")
__gshared immutable(quark) PROP_FRAME_XY;

/**
    X frame index.
*/
@propkey("frame.x")
__gshared immutable(quark) PROP_FRAME_X;

/**
    Y frame index.
*/
@propkey("frame.y")
__gshared immutable(quark) PROP_FRAME_Y;
