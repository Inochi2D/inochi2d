/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.math.transform;
import inochi2d.math;

/**
    A transform

    TODO: Optimize this code by storing everything as a mat3?
*/
class Transform {
private:
    // Matrix transform code
    mat4 g_matrix() {
        return 
            mat4.scaling(scale.x, scale.y, 1) * 
            mat4.zrotation(rotation) * 
            mat4.translation(position.x-origin.x, position.y-origin.y, 1);
    }

public:
    /**
        The transform's parent
    */
    Transform parent;

    /**
        Position of the transform
    */
    vec2 position = vec2(0, 0);

    /**
        The transform's origin
    */
    vec2 origin = vec2(0, 0);

    /**
        The scale of the transform
    */
    vec2 scale = vec2(1, 1);

    /**
        The rotation of the transform
    */
    float rotation = 0f;

    /**
        Gets the matrix associated with this transform
    */
    mat4 matrix() {
        return parent is null ? g_matrix : g_matrix * parent.matrix;
    }
}