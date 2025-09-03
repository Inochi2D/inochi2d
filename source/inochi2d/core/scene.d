/**
    Inochi2D Scene Abstraction

    Scenes provide the top level rendering context for puppets.

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.scene;
import inochi2d.core.puppet;
import inochi2d.core.render;
import inochi2d.core.math;
import nulib.io.stream;
import numem;
import nulib;

/**
    A scene.
*/
final
class Scene : NuRefCounted {
private:
@nogc:
    vector!Puppet puppets;
    recti viewport_;

public:

    /**
        The active camera for the scene.
    */
    Camera camera;

    /**
        The viewport for the scene.
    */
    @property recti viewport() => viewport_;
    @property auto viewport(recti viewport) {
        this.viewport_ = viewport;

        this.camera.size = vec2(viewport_.width, viewport_.height);
        this.camera.update();
        return this;
    }

    // Destructor
    ~this() {
        nogc_delete(camera);
    }

    /**
        Constructor.
    */
    this() {
        this.camera = nogc_new!Camera2D();
    }

    /**
        Updates the scene, updating and re-drawing
        every puppet in the scene.
    */
    void update(float delta) {
        foreach(puppet; puppets) {
            assumeNoGC(&puppet.update, delta);
            assumeNoGC(&puppet.draw, delta);
        }
    }

    /**
        Loads an Inochi2D puppet from a stream into the scene.

        Params:
            stream = The stream to load the puppet from.
    */
    void loadPuppet(Stream stream) {

    }

    /**
        Removes the given puppet from the scene.

        Params:
            puppet = The puppet to remove.
    */
    void remove(Puppet puppet) {
        foreach(i; 0..puppets.length) {
            if (puppets[i] is puppet) {
                puppets.removeAt(i);
                return;
            }
        }
    }
}