/*
    Inochi2D Animation Submodule
    
    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.animation;

public import inochi2d.core.animation.animation;

import inochi2d.core.puppet;
import inochi2d;
import inmath;

class AnimationPlayer {
private:

    // A reference to a currently playing animation
    struct PlayingAnimation {
        /// Name
        string name;

        /// Animation
        Animation* animation;

        /// When it started
        float startTime;

        /// Whether it loops
        bool looping;

        /// Whether the animation is running
        bool running;
    }

    Puppet parent;

    float crossfadeStart;
    PlayingAnimation* prevAnimation;
    PlayingAnimation* currAnimation;

    // All the additive animations
    PlayingAnimation[] additiveAnimations;


public:

    /**
        How many frames of crossfade
    */
    float crossfadeFrames = 300;

    /**
        Constructs a new AnimationPlayer
    */
    this(Puppet puppet) {
        this.parent = puppet;
    }

    /**
        Play an animation
    */
    void play(string animation, bool looping=false, bool blend=false) {
        Animation[string] anims = parent.getAnimations();

        // Early out if the animation doesn't exist.
        if (animation !in anims) return;

        if (anims[animation].additive) {
            
            // Restart the animation if we already have it around.
            foreach(ref additive; additiveAnimations) {
                if (additive.name == animation) {
                    additive.startTime = currentTime();
                    return;
                }
            }

            additiveAnimations ~= PlayingAnimation(animation, &anims[animation], currentTime());
        } else {

            // Set previous animation if we should blend between them
            if (blend) {
                prevAnimation = currAnimation;
                prevAnimation.running = false;
                crossfadeStart = currentTime();
            } else {
                prevAnimation = null;
            }

            currAnimation = new PlayingAnimation(animation, &anims[animation], currentTime());
            currAnimation.running = true;
        }

    }

    /**
        Stops the current main animation
    */
    void stop(string animation, bool immediately=false) {
        if (currAnimation && currAnimation.name == animation) {

            if (immediately) {

                // Immediately destroy the animations, 
                // ending them instantaneously.
                currAnimation = null;
                prevAnimation = null;

            } else currAnimation.running = false; // Tell the animation nicely to end otherwise.

        } else {

            // There can be multiple additive animations,
            // so we need to iterate over them all (even if they're already not running)
            foreach(i; 0..additiveAnimations.length) {
                import std.algorithm.mutation : remove;

                if (additiveAnimations[i].name == animation) {
                    
                    if (immediately) {
                        // Immediately destroy the animation, 
                        // ending it instantaneously.
                        additiveAnimations = additiveAnimations.remove(i);

                    } else additiveAnimations[i].running = false; // Tell the animation nicely to end otherwise.
                }
            }
        }
    }

    void stopAll(bool immediately=false) {
        if (immediately) {

            // Immediately destroy the animations, 
            // ending them instantaneously.
            currAnimation = null;
            prevAnimation = null;
            additiveAnimations.length = 0;
        } else {

            // Set all the animation states to not running.
            // They'll self-destruct once they've reached the end.
            if (currAnimation) currAnimation.running = false;
            if (prevAnimation) prevAnimation.running = false;
            foreach(ref anim; additiveAnimations) anim.running = false;
        }
    }

    /**
        Run an animation step
    */
    void step() {
        float currTime = currentTime();

        // If we have any animation to step through
        if (currAnimation) {
            float mainAnimTime = currTime-currAnimation.startTime;

            // Frame is stored as a float so that we can have half-frames for higher refresh rate monitors.
            float currFrame = mainAnimTime/currAnimation.animation.timestep;

            float loopStart = currAnimation.animation.leadIn < 0 ?                                        0.0 : cast(float)currAnimation.animation.leadIn;
            float loopEnd = currAnimation.animation.leadOut < 0 ?   cast(float)currAnimation.animation.length : cast(float)currAnimation.animation.leadOut;
            float loopLength = loopEnd-loopStart;

            // Handle looping.
            // If we are running, looping, past our loop starting point AND past the loop ending point
            // Then we loop.
            if (currAnimation.running && currAnimation.looping && currFrame > loopStart && currFrame > loopEnd) {
                currFrame = loopStart+(mod(currFrame-loopStart, loopLength));
            }

            // Iterate and step all the lanes in the current animation
            foreach(ref AnimationLane lane; currAnimation.animation.lanes) {
                float value = lane.get(currFrame);
                
                switch(lane.target) {
                    case AnimationLaneTarget.Parameter:
                        lane.paramRef.targetParam.value.vector[lane.paramRef.targetAxis] = value;
                        break;

                    case AnimationLaneTarget.Node:
                        lane.nodeRef.targetNode.setValue(lane.nodeRef.targetName, value);
                        break;

                    default: assert(0);
                }
            }

            // Crossfade T
            float ct;
            if (crossfadeFrames <= 0) ct = 1;
            else ct = ((currTime-crossfadeStart)/currAnimation.animation.timestep)/crossfadeFrames;

            // If current animation is stopping
            if (!currAnimation.running) {

                if (ct >= 1) {
                    
                    // We're done fading, yeet!
                    prevAnimation = null;
                    currAnimation = null;

                } else {

                    // Fading logic
                    foreach(ref AnimationLane lane; currAnimation.animation.lanes) {

                        // TODO: Allow user to set fade out interpolation?
                        switch(lane.target) {
                            case AnimationLaneTarget.Parameter:

                                lane.paramRef.targetParam.value.vector[lane.paramRef.targetAxis] = lerp(
                                    lane.get(currFrame),
                                    lane.paramRef.targetParam.defaults.vector[lane.paramRef.targetAxis],
                                    ct
                                );
                                break;

                            case AnimationLaneTarget.Node:
                                lane.nodeRef.targetNode.setValue(lane.nodeRef.targetName, lerp(
                                    lane.get(currFrame),
                                    lane.nodeRef.targetNode.getDefaultValue(lane.nodeRef.targetName),
                                    ct
                                ));
                                break;

                            default: assert(0);
                        }
                    }
                }

            } else {

                if (ct >= 1) {
                    prevAnimation = null;
                } else {
                    float prevAnimTime = currTime-prevAnimation.startTime;
                    float prevCurrFrame = prevAnimTime/prevAnimation.animation.timestep;

                    // Crossfade logic
                    foreach(ref AnimationLane lane; currAnimation.animation.lanes) {

                        // TODO: Allow user to set fade out interpolation?
                        switch(lane.target) {
                            case AnimationLaneTarget.Parameter:

                                lane.paramRef.targetParam.value.vector[lane.paramRef.targetAxis] = lerp(
                                    lane.get(prevCurrFrame),
                                    lane.paramRef.targetParam.value.vector[lane.paramRef.targetAxis],
                                    ct
                                );
                                break;

                            case AnimationLaneTarget.Node:
                                lane.nodeRef.targetNode.setValue(lane.nodeRef.targetName, lerp(
                                    lane.get(prevCurrFrame),
                                    lane.paramRef.targetParam.value.vector[lane.paramRef.targetAxis],
                                    ct
                                ));
                                break;

                            default: assert(0);
                        }
                    }
                }
            }
        }

        // TODO: Additive animations
        foreach(ref anim; additiveAnimations) { }
    }


}