/*
    Inochi2D Camera

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.math.camera;
import inochi2d.math;
import inochi2d;

/**
    An orthographic camera
*/
class Camera {
private:
    mat4 projection;

public:

    this() {
        position = vec2(0, 0);
    }

    /**
        Position of camera
    */
    vec2 position;

    /**
        Size of the camera
    */
    vec2 size = vec2(640, 480);

    /**
        Matrix for this camera

        width = width of camera area
        height = height of camera area
    */
    mat4 matrix() {
        return 
            mat4.orthographic(0f, cast(float)size.x, cast(float)size.y, 0, 0, ushort.max) * 
            mat4.translation(position.x+(size.x/2), position.y+(size.y/2), -(ushort.max/2));
    }
}