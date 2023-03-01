module inochi2d.core.animation.player;
import inochi2d.core.puppet;
import inochi2d.core.animation;
import inochi2d.core.param;
import inmath;

class AnimationPlayer {
private:
    Puppet puppet;
    AnimationPlaybackRef[] playingAnimations;

public:
    /**
        Whether to snap to framerate
    */
    bool snapToFramerate = false;

    /**
        Construct animation player
    */
    this(Puppet puppet) {
        this.puppet = puppet;
    }

    /**
        Run an update step for the animation player
    */
    void update(float delta) {
        foreach(ref anim; playingAnimations) {
            if (anim.valid) anim.update(delta);
        }
    }

    /**
        Gets an animation
    */
    AnimationPlaybackRef createOrGet(string name) {

        // Try fetching from pre-existing
        foreach(ref AnimationPlaybackRef anim; playingAnimations) {
            if (anim._name == name) return anim;
        }

        // Create new playback
        if (Animation* anim = name in puppet.getAnimations()) {
            playingAnimations ~= new AnimationPlayback(this, anim, name);
            return playingAnimations[$-1];
        }

        // Invalid state
        return null;
    }

    /**
        Convenience function which plays an animation
    */
    AnimationPlaybackRef play(string name) {
        auto anim = createOrGet(name);
        if (anim) {
            anim.play();
        }

        return anim;
    }

    /**
        pre-render one frame of all animations
    */
    void prerenderAll() {
        foreach(anim; playingAnimations) {
            anim.render();
        }
    }

    /**
        Stop all animations
    */
    void stopAll(bool immediate=false) {
        foreach(anim; playingAnimations) {
            anim.stop(immediate);
        }
    }

    /**
        Destroy all animations
    */
    void destroyAll() {
        foreach(anim; playingAnimations) {
            anim.valid = false;
        }
        playingAnimations.length = 0;
    }
}

struct AnimationPlayback {
private:
    // Base Refs
    AnimationPlayer player;
    Animation*      anim;
    bool            valid = true;
    string          _name;

    // Runtime
    bool    _playLeadOut = false;
    bool    _paused = false;
    bool    _playing = false;
    bool    _looping = false;
    bool    _stopping = false;
    float   _time = 0;
    float   _strength = 1;
    float   _speed = 1;
    int     _looped = 0;

    ref Puppet getPuppet() { return player.puppet; }

    this(AnimationPlayer player, Animation* anim, string name) {
        this.player = player;
        this.anim = anim;
        this._name = name;
        this._paused = false;
        this._playing = false;
        this._looping = false;
        this._playLeadOut = false;
    }
    
    // Internal functions

    void update(float delta) {
        if (!valid || !isRunning) return;
        if (_paused) {
            render();
            return;
        }

        // Time step
        _time += delta;

        // Handle looping
        if (!isPlayingLeadOut && looping && frame >= loopPointEnd) {
            _time = cast(float)loopPointBegin*anim.timestep;
            _looped++;
        }

        render();

        // Handle stopping animation completely on lead-out end
        if (!_looping && isPlayingLeadOut()) {
            if (frame+1 >= anim.length) {
                _playing = false;
                _playLeadOut = false;
                _stopping = false;
                _time = 0;
                _looped = 0;
            }
        }
    }

public:
    /// Gets the name of the animation
    string name() { return _name; }

    /// Gets whether the animation has run to end
    bool eof() { return frame >= anim.length; }

    /// Gets whether this instance is valid
    bool isValid() { return valid; }

    /// Gets whether this instance is currently playing
    bool playing() { return _playing; }

    /// Gets whether this instance is currently stopping
    bool stopping() { return _stopping; }

    /// Gets whether this instance is currently paused
    bool paused() { return _paused; }

    /// Gets or sets whether this instance is looping
    bool looping() { return _looping; }
    bool looping(bool value) { _looping = value; return value; }
    
    /// Gets how many times the animation has looped
    int looped() { return _looped; }

    /// Gets or sets the speed multiplier for the animation
    float speed() { return _speed; }
    float speed(bool value) { _speed = clamp(value, 1, 10); return value; }

    /// Gets or sets the strength multiplier (0..1) for the animation
    float strength() { return _strength; }
    float strength(float value) { _strength = clamp(value, 0, 1); return value; }

    /// Gets the current frame of animation
    int frame() { return cast(int)round(_time / anim.timestep); }

    /// Gets the current floating point (half-)frame of animation
    float hframe() { return _time / anim.timestep; }
    
    /// Gets the frame looping ends at
    int loopPointEnd() { return hasLeadOut ? anim.leadOut : anim.length; }
    
    /// Gets the frame looping begins at
    int loopPointBegin() { return hasLeadIn ? anim.leadIn : 0; }

    /// Gets whether the animation has lead-in
    bool hasLeadIn() { return anim.leadIn > 0 && anim.leadIn+1 < anim.length; }

    /// Gets whether the animation has lead-out
    bool hasLeadOut() { return anim.leadOut > 0 && anim.leadOut+1 < anim.length; }

    /// Gets whether the animation is playing the leadout
    bool isPlayingLeadOut() { return ((_playing && !_looping) || _stopping) && _playLeadOut && frame < anim.length; }

    /// Gets whether the animation is playing the main part or lead out
    bool isRunning() { return _playing || isPlayingLeadOut; }

    /// Gets the framerate of the animation
    int fps() { return cast(int)(1000.0 / (anim.timestep * 1000.0)); }

    /// Gets playback seconds
    int seconds() { return cast(int)_time; }

    /// Gets playback miliseconds
    int miliseconds() { return cast(int)((_time - cast(float)seconds) * 1000); }

    /// Gets length in frames
    int frames() { return anim.length; }

    /// Gets the backing animation for the current playback
    Animation* animation() { return anim; }

    /// Gets the playback ID
    ptrdiff_t playbackId() {
        ptrdiff_t idx = -1;
        foreach(i, ref sanim; player.playingAnimations) 
            if (sanim._name == this._name) idx = i;
        
        return idx;
    }

    /**
        Destroys this animation instance
    */
    void destroy() {
        import std.algorithm.mutation : remove;
        import std.algorithm.searching : countUntil;

        this.valid = false;
        if (playbackId > -1) player.playingAnimations = player.playingAnimations.remove(playbackId);
    }

    /**
        Plays the animation
    */
    void play(bool loop=false, bool playLeadOut=true) {
        if (_paused) _paused = false;
        else {
            _looped = 0;
            _time = 0;
            _stopping = false;
            _playing = true;
            _looping = loop;
            _playLeadOut = playLeadOut;
        }
    }

    /**
        Pauses the animation
    */
    void pause() {
        _paused = true;
    }

    /**
        Stops the animation
    */
    void stop(bool immediate=false) {
        if (_stopping) return;

        bool shouldStopImmediate = immediate || frame == 0 || _paused || !hasLeadOut;
        _stopping = !shouldStopImmediate;
        _looping = false;
        _paused = false;
        _playing = false;
        _playLeadOut = !shouldStopImmediate;
        if (shouldStopImmediate) {
            _time = 0;
            _looped = 0;
        }
    }

    /**
        Seeks the animation
    */
    void seek(int frame) {
        float frameTime = clamp(frame, 0, frames);
        _time = frameTime*anim.timestep;
        _looped = 0;
    }
    
    /**
        Renders the current frame of animation

        Called internally automatically by the animation player
    */
    void render() {

        // Apply lanes
        float realStrength = clamp(_strength, 0, 1);
        foreach(lane; anim.lanes) {
            lane.paramRef.targetParam.pushIOffsetAxis(
                lane.paramRef.targetAxis, 
                lane.get(hframe, player.snapToFramerate)*realStrength,
                lane.mergeMode
            );
        }
    }

}

alias AnimationPlaybackRef = AnimationPlayback*;