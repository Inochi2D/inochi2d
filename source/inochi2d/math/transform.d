/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.math.transform;
public import inochi2d.math;

/**
    A transform
*/
struct Transform {
private:
    mat4 trs;

public:

    /**
        The translation of the transform
    */
    vec3 translation = vec3(0, 0, 0);

    /**
        The rotation of the transform
    */
    quat rotation = quat.identity;

    /**
        The scale of the transform
    */
    vec2 scale = vec2(1, 1);

    /**
        Whether rotation should be locked
    */
    bool lockRotation = false;

    /**
        Initialize a transform
    */
    this(vec3 translation, quat rotation = quat.identity, vec2 scale = vec2(1, 1)) {
        this.translation = translation;
        this.rotation = rotation;
        this.scale = scale;
    }

    /**
        Returns the result of 2 transforms multiplied together
    */
    Transform opBinary(string op : "*")(Transform other) {
        Transform tnew;
        
        if (lockRotation) {
            tnew.trs = mat4.translation(vec3(other.trs * vec4(this.translation, 1)));
            tnew.translation = vec3(other.trs * vec4(this.translation, 1));
        } else {
            tnew.trs = other.trs * this.trs;
            tnew.translation = vec3(other.trs * vec4(this.translation, 1));
        }
        return tnew;
    }

    /**
        Gets the matrix for this transform

        TODO: make this cached and lazy updated?
    */
    mat4 matrix() {
        return trs;
    }

    /**
        Updates the internal matrix of this transform
    */
    void update() {
        trs = mat4.scaling(scale.x, scale.y, 1) * rotation.to_matrix!(4, 4) * mat4.translation(translation);
    }

    string toString() {
        import std.format : format;
        return "%s,\n%s,\n%s\n%s".format(trs.toPrettyString, translation.toString, rotation.toString, scale.toString);
    }
}