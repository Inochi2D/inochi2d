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
    mat4 trs = mat4.identity;
    mat4 translation_ = mat4.identity;
    mat4 rotation_ = mat4.identity;
    mat4 scale_ = mat4.identity;
    mat4 offset_ = mat4.identity;

public:

    /**
        The origin of the transform
    */
    vec2 origin = vec2(0, 0);

    /**
        The translation of the transform
    */
    vec3 translation = vec3(0, 0, 0);

    /**
        The rotation of the transform
    */
    vec3 rotation = vec3(0, 0, 0);//; = quat.identity;

    /**
        The scale of the transform
    */
    vec2 scale = vec2(1, 1);

    /**
        Locks rotation on the X axis
    */
    bool lockRotationX = false;

    /**
        Locks rotation on the Y axis
    */
    bool lockRotationY = false;
    
    /**
        Locks rotation on the Z axis
    */
    bool lockRotationZ = false;

    /**
        Sets the locking value for all rotation axies
    */
    void lockRotation(bool value) { lockRotationX = lockRotationY = lockRotationZ = value; }

    /**
        Locks translation on the X axis
    */
    bool lockTranslationX = false;

    /**
        Locks translation on the Y axis
    */
    bool lockTranslationY = false;
    
    /**
        Locks translation on the Z axis
    */
    bool lockTranslationZ = false;

    /**
        Sets the locking value for all translation axies
    */
    void lockTranslation(bool value) { lockTranslationX = lockTranslationY = lockTranslationZ = value; }

    /**
        Locks scale on the X axis
    */
    bool lockScaleX = false;

    /**
        Locks scale on the Y axis
    */
    bool lockScaleY = false;

    /**
        Locks all scale axies
    */
    void lockScale(bool value) { lockScaleX = lockScaleY = value; }

    /**
        Initialize a transform
    */
    this(vec3 translation, vec3 rotation = vec3(0), vec2 scale = vec2(1, 1)) {
        this.translation = translation;
        this.rotation = rotation;
        this.scale = scale;
    }

    /**
        Returns the result of 2 transforms multiplied together
    */
    Transform opBinary(string op : "*")(Transform other) {
        Transform tnew;
        tnew.origin = other.origin;

        //
        //  ROTATION
        //

        quat rot = quat.from_matrix(mat3(this.rotation_ * other.rotation_));

        // Handle rotation locks
        if (!lockRotationX) tnew.rotation.x = rot.roll;
        if (!lockRotationY) tnew.rotation.y = rot.pitch;
        if (!lockRotationZ) tnew.rotation.z = rot.yaw;
        tnew.rotation_ = quat.euler_rotation(tnew.rotation.x, tnew.rotation.y, tnew.rotation.z).to_matrix!(4, 4);

        //
        //  TRANSLATION
        //

        // Calculate new TRS
        vec3 trans = vec3(
            // We want to support parts being placed correctly even if they're rotation locked
            // therefore we need to apply the worldspace rotation here
            // That has been pre-calculated above.
            // Do note we also multiply by its inverse, this is so that the rotations don't
            // start stacking up weirdly causing cascadingly more extreme rotation.
            tnew.rotation_ * this.translation_ * tnew.rotation_.inverse() * 

            // Also our local translation
            vec4(other.translation, 1)
        );

        // Handle translation locks
        if (!lockTranslationX) tnew.translation.x = trans.x;
        if (!lockTranslationY) tnew.translation.y = trans.y;
        if (!lockTranslationZ) tnew.translation.z = trans.z;

        //
        //  SCALE
        //

        // Handle scale locks
        vec2 scale = vec2(this.scale_ * vec4(other.scale, 1, 1));
        if (!lockScaleX) tnew.scale.x = scale.x;
        if (!lockScaleY) tnew.scale.y = scale.y;

        tnew.update();

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
        offset_ = mat4.translation(vec3(origin, 0));
        translation_ = mat4.translation(translation);
        rotation_ = quat.euler_rotation(this.rotation.x, this.rotation.y, this.rotation.z).to_matrix!(4, 4);
        scale_ = mat4.scaling(scale.x, scale.y, 1);
        trs =  translation_ * rotation_ * scale_ * offset_;
    }

    string toString() {
        import std.format : format;
        return "%s,\n%s,\n%s\n%s".format(trs.toPrettyString, translation.toString, rotation.toString, scale.toString);
    }
}