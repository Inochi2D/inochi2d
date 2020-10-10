/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.inochi2d.scene;
import inochi2d.math;

/**
    A scene
*/
class Scene {
public:

    /**
        The scene's viewport
    */
    vec2i viewport;

    /**
        The scene's camera
    */
    Camera camera;
}