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


    void reconstruct(Puppet puppet) {
        foreach(ref lane; lanes.dup) lane.reconstruct(puppet);
    }

    /**
        Finalizes the animation
    */
    void finalize(Puppet puppet) {
        foreach(ref lane; lanes) lane.finalize(puppet);
    }

    /**
        Serialization function
    */
    void serialize(ref InochiSerializer serializer) {
        auto obj = serializer.structBegin();
            serializer.putKey("timestep");
            serializer.serializeValue(timestep);
            serializer.putKey("additive");
            serializer.serializeValue(additive);
            serializer.putKey("length");
            serializer.serializeValue(length);
            serializer.putKey("timestep");
            serializer.serializeValue(timestep);
            serializer.putKey("leadIn");
            serializer.serializeValue(leadIn);
            serializer.putKey("leadOut");
            serializer.serializeValue(leadOut);
            serializer.putKey("animationWeight");
            serializer.serializeValue(animationWeight);

            serializer.putKey("lanes");
            auto state = serializer.listBegin;
            foreach(lane; lanes) {
                if (lane.paramRef.targetParam) {
                    serializer.elemBegin;
                    serializer.serializeValue(lane);
                }
            }
            serializer.listEnd(state);
        serializer.structEnd(obj);
    }

    /**
        Deserialization function
    */
    SerdeException deserializeFromFghj(Fghj data) {
        data["timestep"].deserializeValue(this.timestep);
        data["additive"].deserializeValue(this.additive);
        if (!data["animationWeight"].isEmpty) data["animationWeight"].deserializeValue(this.animationWeight);
        data["length"].deserializeValue(this.length);
        data["leadIn"].deserializeValue(this.leadIn);
        data["leadOut"].deserializeValue(this.leadOut);
        data["lanes"].deserializeValue(this.lanes);
        return null;
    }
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

/**
    Animation Lane
*/
struct AnimationLane {
private:
    uint refuuid;

public:

    /**
        Reference to parameter if any
    */
    AnimationParameterRef* paramRef;

    /**
        Serialization function
    */
    void serialize(ref InochiSerializer serializer) {
        auto obj = serializer.structBegin();
            serializer.putKey("interpolation");
            serializer.serializeValue(interpolation);

            if (paramRef) {
                serializer.putKey("uuid");
                serializer.putValue(paramRef.targetParam.uuid);
                serializer.putKey("target");
                serializer.putValue(paramRef.targetAxis);
            }

            serializer.putKey("keyframes");
            serializer.serializeValue(frames);

            serializer.putKey("merge_mode");
            serializer.serializeValue(mergeMode);
        serializer.structEnd(obj);
    }

    /**
        Deserialization function
    */
    SerdeException deserializeFromFghj(Fghj data) {
        data["interpolation"].deserializeValue(this.interpolation);
        data["uuid"].deserializeValue(refuuid);

        this.paramRef = new AnimationParameterRef(null, 0);
        data["target"].deserializeValue(this.paramRef.targetAxis);

        data["keyframes"].deserializeValue(this.frames);
        if (!data["merge_mode"].isEmpty) data["merge_mode"].deserializeValue(this.mergeMode);
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
        Merging mode of the lane
    */
    ParamMergeMode mergeMode = ParamMergeMode.Forced;

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
                if (frames[i].frame < frame) continue;

                // Fallback to not try to index frame -1
                if (i == 0) return frames[0].value;

                // Interpolation "time" 0->1
                // Note we use floats here in case you're running the
                // update step faster than the timestep of the animation
                // This way it won't look choppy
                float tonext = cast(float)frames[i].frame-frame;
                float ilen = (cast(float)frames[i].frame-cast(float)frames[i-1].frame);
                float t = 1-(tonext/ilen);

                // Interpolation tension 0->1
                float tension = frames[i].tension;

                switch(interpolation) {
                    
                    // Nearest - Snap to the closest frame
                    case InterpolateMode.Nearest:
                        return t > 0.5 ? frames[i].value : frames[i-1].value;

                    // Stepped - Snap to the current active keyframe
                    case InterpolateMode.Stepped:
                        return frames[i-1].value;

                    // Linear - Linearly interpolate between frame A and B
                    case InterpolateMode.Linear:
                        return lerp(frames[i-1].value, frames[i].value, t);

                    // Cubic - Smoothly in a curve between frame A and B
                    case InterpolateMode.Cubic:
                        float prev = frames[max(cast(ptrdiff_t)i-2, 0)].value;
                        float curr = frames[max(cast(ptrdiff_t)i-1, 0)].value;
                        float next1 = frames[min(cast(ptrdiff_t)i, frames.length-1)].value;
                        float next2 = frames[min(cast(ptrdiff_t)i+1, frames.length-1)].value;

                        // TODO: Switch formulae, catmullrom interpolation
                        return cubic(prev, curr, next1, next2, t);
                        
                    // Bezier - Allows the user to specify beziér curves.
                    case InterpolateMode.Bezier:
                        // TODO: Switch formulae, Beziér curve
                        return lerp(frames[i-1].value, frames[i].value, clamp(hermite(0, 2*tension, 1, 2*tension, t), 0, 1));

                    default: assert(0);
                }
            }
            return frames[$-1].value;
        }

        // Fallback, no values.
        // Ideally we won't even call this function
        // if there's nothing to do.
        return 0;
    }

    void reconstruct(Puppet puppet) { }
    
    void finalize(Puppet puppet) {
        if (paramRef) paramRef.targetParam = puppet.findParameter(refuuid);
    }

    /**
        Updates the order of the keyframes
    */
    void updateFrames() {
        import std.algorithm.sorting : sort;
        import std.algorithm.mutation : SwapStrategy;
        sort!((a, b) => a.frame < b.frame, SwapStrategy.stable)(frames);
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