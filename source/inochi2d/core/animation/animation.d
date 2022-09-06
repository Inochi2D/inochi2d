module inochi2d.core.animation.animation;
import inochi2d.core;
import inochi2d.fmt.serialize;
import inmath;
import inmath.interpolate;

/**
    An animation
*/
struct Animation {
public:

    /**
        The timestep of each frame
    */
    float timestep = 0.0166;
    
    /**
        Whether the animation is additive.

        Additive animations will not replace main animations, but add their data
        on top of the running main animation
    */
    bool additive;

    /**
        The weight of the animation

        This is only relevant for additive animations
    */
    float animationWeight;

    /**
        All of the animation lanes in this animation
    */
    AnimationLane[] lanes;

    /**
        Length in frames
    */
    int length;

    /**
        Time where the lead-in ends
    */
    int leadIn = -1;

    /**
        Time where the lead-out starts
    */
    int leadOut = -1;

    /**
        Finalizes the animation
    */
    void finalize(Puppet puppet) {
        foreach(ref lane; lanes) lane.finalize(puppet);
    }
}

enum AnimationLaneTarget {
    Parameter,
    Node
}

struct AnimationParameterRef {

    /**
        A parameter to target
    */
    Parameter targetParam;

    /**
        Target axis of the parameter
    */
    int targetAxis;

}

struct AnimationNodeRef {

    /**
        A node to target
    */
    Node targetNode;

    /**
        Name of target setter for node
    */
    string targetName;

}

/**
    Animation Lane
*/
struct AnimationLane {
private:
    uint refuuid;

public:
    /**
        The type of target the lane applies to
    */
    AnimationLaneTarget target;

    /**
        Reference to parameter if any
    */
    AnimationParameterRef* paramRef;

    /**
        Reference to node if any
    */
    AnimationNodeRef* nodeRef;

    /**
        Serialization function
    */
    void serialize(ref InochiSerializer serializer) {
        serializer.putKey("type");
        serializer.serializeValue(target);
        
        serializer.putKey("interpolation");
        serializer.serializeValue(interpolation);

        if (paramRef) {
            serializer.putKey("uuid");
            serializer.putValue(paramRef.targetParam.uuid);
            serializer.putKey("target");
            serializer.putValue(paramRef.targetAxis);
        }
    
        if (nodeRef) {
            serializer.putKey("uuid");
            serializer.putValue(nodeRef.targetNode.uuid);
            serializer.putKey("target");
            serializer.putValue(nodeRef.targetName);
        }

        serializer.putKey("keyframes");
        serializer.serializeValue(frames);
    }

    /**
        Deserialization function
    */
    SerdeException deserializeFromFghj(Fghj data) {
        data["type"].deserializeValue(this.target);
        data["interpolation"].deserializeValue(this.interpolation);
        
        data["uuid"].deserializeValue(refuuid);

        switch(target) {
            case AnimationLaneTarget.Node:
                this.nodeRef = new AnimationNodeRef(null, null);
                data["target"].deserializeValue(this.nodeRef.targetName);
                break;
            case AnimationLaneTarget.Parameter:
                this.paramRef = new AnimationParameterRef(null, 0);
                data["target"].deserializeValue(this.paramRef.targetAxis);
                break;
            default: assert(0);
        }

        data["keyframes"].deserializeValue(this.frames);
        return null;
    }

    /**
        List of frames in the lane
    */
    Keyframe[] frames;

    /**
        The interpolation between each frame in the lane
    */
    InterpolateMode interpolation;

    /**
        Gets the interpolated state of a frame of animation 
        for this lane
    */
    float get(float frame, bool snapSubframes=false) {
        if (frames.length > 0) {

            // If subframe snapping is turned on then we'll only run at the framerate
            // of the animation, without any smooth interpolation on faster app rates.
            if (snapSubframes) frame = floor(frame);

            // Fallback if there's only 1 frame
            if (frames.length == 1) return frames[0].value;

            foreach(i; 0..frames.length) {
                if (frames[i].frame > frame) {

                    // Fallback to not try to index frame -1
                    if (i == 0) return frames[0].value;

                    // Interpolation "time" 0->1
                    // Note we use floats here in case you're running the
                    // update step faster than the timestep of the animation
                    // This way it won't look choppy
                    float t = (frame-cast(float)frames[i-1].frame);

                    // Interpolation tension 0->1
                    float tension = frames[i].tension;

                    switch(interpolation) {
                        
                        // Nearest - Snap to the closest frame
                        case InterpolateMode.Nearest:
                            return t > 0.5 ? frames[i].value : frames[i-1].value;

                        // Stepped - Snap to the current active keyframe
                        case InterpolateMode.Stepped:
                            return frames[i].value;

                        // Linear - Linearly interpolate between frame A and B
                        case InterpolateMode.Linear:
                            return lerp(frames[i-1].value, frames[i].value, t);

                        // Cubic - Smoothly in a curve between frame A and B
                        case InterpolateMode.Cubic:
                            // TODO: Switch formulae, catmullrom interpolation
                            return lerp(frames[i-1].value, frames[i].value, clamp(hermite(0, 2*(1-tension), 1, 2*tension, t), 0, 1));
                            
                        // Bezier - Allows the user to specify beziér curves.
                        case InterpolateMode.Bezier:
                            // TODO: Switch formulae, Beziér curve
                            return lerp(frames[i-1].value, frames[i].value, clamp(hermite(0, 2*tension, 1, 2*tension, t), 0, 1));

                        default: assert(0);
                    }
                }
            }
            return frames[$-1].value;
        }

        // Fallback, no values.
        // Ideally we won't even call this function
        // if there's nothing to do.
        return 0;
    }

    void finalize(Puppet puppet) {
        if (nodeRef) nodeRef.targetNode = puppet.find(refuuid);
        if (paramRef) paramRef.targetParam = puppet.findParameter(refuuid);
    }
}

/**
    A keyframe
*/
struct Keyframe {
    /**
        The frame at which this frame occurs
    */
    int frame;

    /**
        The value of the parameter at the given frame
    */
    float value;

    /**
        Interpolation tension for cubic/inout
    */
    float tension = 0.5;
}