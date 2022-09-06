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

        /// The playhead (time in ms since start)
        float time = 0;

        /// Whether it loops
        bool looping = false;

        /// Whether the animation is running
        bool running = true;

        /// Whether the animation is paused
        bool paused = false;

        /**
            Advances time for the animation
        */
        void advance(float delta) {
            if (!paused) {
                time += delta;
            
                // Animations needs to be both looping AND running before they'll loop
                // Eg. if an animation ends then it should play the lead out if possible.
                if (looping && running) {
                    float loopStart = (animation.leadIn == -1 ? 0 : animation.leadIn)*animation.timestep;
                    float loopEnd = (animation.leadOut == -1 ? animation.length : animation.leadOut)*animation.timestep;
                    time = loopStart+mod(time-loopStart, loopEnd-loopStart);
                }
            }
        }
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
        Sets or pushes an animation either as a main or additive animation

        This does not respect the animation mode set for the animation.

        Animations are added in a paused state, use play to play them.
    */
    void set(string animation, bool asMain) {
        Animation[string] anims = parent.getAnimations();

        // Early out if the animation doesn't exist.
        if (animation !in anims) return;

        if (asMain) {
            currAnimation = new PlayingAnimation;
            currAnimation.name = animation;
            currAnimation.animation = &anims[animation];
            currAnimation.time = 0;
            currAnimation.paused = true;

        } else {
            
            // If the current additive animations contain the animation then
            // don'tdo anything.
            foreach(ref additive; additiveAnimations) {
                if (additive.name == animation) return;   
            }

            PlayingAnimation anim = { name: animation, animation: &anims[animation], time: 0, paused: true };
            additiveAnimations ~= anim; 
        }
    }

    /**
        Play an animation
    */
    void play(string animation, bool looping=false, bool blend=false) {
        Animation[string] anims = parent.getAnimations();

        // Early out if the animation doesn't exist.
        if (animation !in anims) return;


        // Attempt to restart main animations
        if (currAnimation && currAnimation.name == animation) {
            if (prevAnimation) prevAnimation.paused = false;
            currAnimation.paused = false;
            return;
        }
        
        // Attempt to restart additive animations
        foreach(ref additive; additiveAnimations) {
            if (additive.name == animation) {
                if (additive.paused) additive.paused = false;
                else additive.time = 0;
                return;
            }
        }

        
        if (anims[animation].additive) {

            // Add new animation to list
            // As above will escape out early it's safe to not return here.
            PlayingAnimation anim = { name: animation, animation: &anims[animation], time: 0, looping: looping };
            additiveAnimations ~= anim; 

        } else {

            // Handle setting up crossfade if it is enabled.
            if (blend) {
                prevAnimation = currAnimation;
                prevAnimation.running = false;

                // NOTE: We set this even if we might not use it
                crossfadeStart = currentTime();
            } else {
                prevAnimation = null;
            }

            // Add our new animation as the current animation
            currAnimation = new PlayingAnimation;
            currAnimation.name = animation;
            currAnimation.animation = &anims[animation];
            currAnimation.time = 0;
            currAnimation.looping = looping;
        }
    }

    /**
        Pause a currently playing animation
    */
    void pause(string animation) {
        Animation[string] anims = parent.getAnimations();

        // Early out if the animation doesn't exist.
        if (animation !in anims) return;

        if (anims[animation].additive) {

            // Restart the animation if we already have it around.
            foreach(ref additive; additiveAnimations) {
                if (additive.name == animation) {
                    additive.paused = true;
                    return;
                }
            }
        } else {
            if (prevAnimation) prevAnimation.paused = true;
            if (currAnimation) currAnimation.paused = true;
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

    /**
        Seek the specified animation to the specified frame
    */
    void seek(string animation, float frame) {
        Animation[string] anims = parent.getAnimations();

        // Early out if the animation doesn't exist.
        if (animation !in anims) return;

        if (anims[animation].additive) {

            // Seek additive animation
            foreach(ref additive; additiveAnimations) {
                if (additive.name == animation) {
                    additive.time = frame*additive.animation.timestep;
                    this.stepOther(0);
                    return;
                }
            }
        } else {

            // Seek main animation
            if (currAnimation) {
                currAnimation.time = frame*currAnimation.animation.timestep;
                this.stepMain(0);
            }
        }

    }

    /**
        Gets the currently playing frame and subframe for the specified animation.
    */
    float tell(string animation) {
        Animation[string] anims = parent.getAnimations();

        // Early out if the animation doesn't exist.
        if (animation !in anims) return 0;

        if (anims[animation].additive) {

            // Seek additive animation
            foreach(ref additive; additiveAnimations) {
                if (additive.name == animation) {
                    return additive.time/additive.animation.timestep;
                }
            }
        } else {

            // Seek main animation
            if (currAnimation) return currAnimation.time/currAnimation.animation.timestep;
        }

        // Fallback: If there's no animation with that name then it's just stuck at frame 0
        return 0;
    }

    /**
        Stop all animations
    */
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
        Step through the main animation
    */
    void stepMain(float delta) {
        if (currAnimation) {

            // Advance time for the animations
            if (prevAnimation) prevAnimation.advance(delta);
            currAnimation.advance(delta);

            // Frame is stored as a float so that we can have half-frames for higher refresh rate monitors.
            float currFrame = currAnimation.time/currAnimation.animation.timestep;

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
            // TODO: Adjust ct based on in/out of animation?
            float ct;
            if (crossfadeFrames <= 0) ct = 1;
            else ct = ((currentTime()-crossfadeStart)/currAnimation.animation.timestep)/crossfadeFrames;

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
                float prevCurrFrame = prevAnimation.time/prevAnimation.animation.timestep;

                if (prevAnimation.animation.leadOut < prevAnimation.animation.length) {
                    ct = (prevCurrFrame-prevAnimation.animation.leadOut)/prevAnimation.animation.length;
                }

                if (ct >= 1) {
                    prevAnimation = null;
                } else {

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
    }

    /**
        Step through the additive animations
    */
    void stepOther(float delta) {
        foreach(ref anim; additiveAnimations) {
            anim.advance(delta);
        }
    }

    /**
        Run an animation step

        Paused animations will automatically be skipped to save processing resources
    */
    void step() {
        float delta = deltaTime();

        // Handle main animation
        if (currAnimation && !currAnimation.paused) this.stepMain(delta);
        this.stepOther(delta); 
    }
}