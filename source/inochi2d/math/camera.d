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

    /**
        Position of camera
    */
    vec2 position = vec2(0, 0);

    /**
        Size of the camera
    */
    vec2 scale = vec2(1, 1);

    /**
        Matrix for this camera

        width = width of camera area
        height = height of camera area
    */
    mat4 matrix() {
        int width, height;
        inGetViewport(width, height);

        vec2 realSize = vec2(cast(float)width/scale.x, cast(float)height/scale.y);
        if(!position.isFinite) position = vec2(0);
        if(!scale.isFinite) scale = vec2(1);
        if(!realSize.isFinite) return mat4.identity;

        return 
            mat4.orthographic(0f, realSize.x, realSize.y, 0, 0, ushort.max) * 
            mat4.translation(position.x+(realSize.x/2), position.y+(realSize.y/2), -(ushort.max/2));
    }
}