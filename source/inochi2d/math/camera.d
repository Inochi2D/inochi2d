/*
    Inochi2D Camera

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.math.camera;
import inochi2d.math;

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
        Matrix for this camera

        width = width of camera area
        height = height of camera area
    */
    mat4 matrix(int width, int height) {
        return 
            mat4.orthographic(0f, cast(float)width, cast(float)height, 0, 0, max(width, height)) * 
            mat4.translation(position.x, position.y, -2);
    }
}