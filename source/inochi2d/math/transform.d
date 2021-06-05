/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.math.transform;
public import inochi2d.math;
import inochi2d.fmt.serialize;

/**
    A transform
*/
struct Transform {
private:
    @Ignore
    mat4 trs = mat4.identity;

    @Ignore
    mat4 translation_ = mat4.identity;

    @Ignore
    mat4 rotation_ = mat4.identity;

    @Ignore
    mat4 scale_ = mat4.identity;

public:

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
        Whether the transform should snap to pixels
    */
    bool pixelSnap = false;

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
        //  SCALE
        //

        // Handle scale locks
        vec2 scale = vec2(this.scale_ * vec4(other.scale, 1, 1));
        if (!lockScaleX) tnew.scale.x = scale.x;
        if (!lockScaleY) tnew.scale.y = scale.y;
        tnew.scale_ = mat4.scaling(scale.x, scale.y, 1);

        //
        //  TRANSLATION
        //

        // Calculate new TRS
        vec3 trans = vec3(
            // We want to support parts being placed correctly even if they're rotation or scale locked
            // therefore we need to apply the worldspace rotation and scale here
            // That has been pre-calculated above.
            // Do note we also multiply by its inverse, this is so that the rotations and scaling doesn't
            // start stacking up weirdly causing cascadingly more extreme transformation.
            tnew.scale_ * tnew.rotation_ * this.translation_ * tnew.rotation_.inverse() * tnew.scale_.inverse() * 

            // Also our local translation
            vec4(other.translation, 1)
        );

        vec3 standAloneTrans = vec3(
            this.translation_ *
            vec4(0, 0, 0, 1)
        );

        // Handle translation locks
        if (!lockTranslationX) tnew.translation.x = pixelSnap ? round(trans.x) : trans.x;
        else tnew.translation.x = pixelSnap ? round(standAloneTrans.x) : standAloneTrans.x;

        if (!lockTranslationY) tnew.translation.y = pixelSnap ? round(trans.y) : trans.y;
        else tnew.translation.y = pixelSnap ? round(standAloneTrans.y) : standAloneTrans.y;

        if (!lockTranslationZ) tnew.translation.z = pixelSnap ? round(trans.z) : trans.z;
        else tnew.translation.z = pixelSnap ? round(standAloneTrans.z) : standAloneTrans.z;

        tnew.update();

        return tnew;
    }

    /**
        Gets the matrix for this transform
    */
    @Ignore
    mat4 matrix() {
        return trs;
    }

    /**
        Updates the internal matrix of this transform
    */
    void update() {
        translation_ = mat4.translation(translation);
        rotation_ = quat.euler_rotation(this.rotation.x, this.rotation.y, this.rotation.z).to_matrix!(4, 4);
        scale_ = mat4.scaling(scale.x, scale.y, 1);
        trs =  translation_ * rotation_ * scale_;
    }

    @Ignore
    string toString() {
        import std.format : format;
        return "%s,\n%s,\n%s\n%s".format(trs.toPrettyString, translation.toString, rotation.toString, scale.toString);
    }

    void serialize(S)(ref S serializer) {
        auto state = serializer.objectBegin();
            serializer.putKey("trans");
            translation.serialize(serializer);
        
            if (lockTranslationX || lockTranslationY || lockTranslationZ) {
                serializer.putKey("trans_lock");
                serializer.serializeValue([lockTranslationX, lockTranslationY, lockTranslationZ]);
            }

            serializer.putKey("rot");
            rotation.serialize(serializer);

            if (lockRotationX || lockRotationY || lockRotationZ) {
                serializer.putKey("rot_lock");
                serializer.serializeValue([lockRotationX, lockRotationY, lockRotationZ]);
            }

            serializer.putKey("scale");
            scale.serialize(serializer);

            if (lockScaleX || lockScaleY) {
                serializer.putKey("scale_lock");
                serializer.serializeValue([lockScaleX, lockScaleY]);
            }

        serializer.objectEnd(state);
    }

    SerdeException deserializeFromAsdf(Asdf data) {
        translation.deserialize(data["trans"]);
        rotation.deserialize(data["rot"]);
        scale.deserialize(data["scale"]);

        // Deserialize locks
        if (data["trans_lock"] != Asdf.init) {
            bool[] states;
            data["trans_lock"].deserializeValue(states);

            this.lockTranslationX = states[0];
            this.lockTranslationY = states[1];
            this.lockTranslationZ = states[2];
        }
        
        if (data["rot_lock"] != Asdf.init) {
            bool[] states;
            data["rot_lock"].deserializeValue(states);

            this.lockRotationX = states[0];
            this.lockRotationY = states[1];
            this.lockRotationZ = states[2];
        }
        
        if (data["scale_lock"] != Asdf.init) {
            bool[] states;
            data["scale_lock"].deserializeValue(states);
            this.lockScaleX = states[0];
            this.lockScaleY = states[1];
        }
        return null;
    }
}
/**
    A 2D transform;
*/
struct Transform2D {
private:
    @Ignore
    mat3 trs;

public:
    /**
        Translate
    */
    vec2 translation;
    /**
        Scale
    */
    vec2 scale;
    
    /**
        Rotation
    */
    float rotation;

    /**
        Gets the matrix for this transform
    */
    mat3 matrix() {
        return trs;
    }

    /**
        Updates the internal matrix of this transform
    */
    void update() {
        mat3 translation_ = mat3.translation(vec3(translation, 0));
        mat3 rotation_ = mat3.zrotation(rotation);
        mat3 scale_ = mat3.scaling(scale.x, scale.y, 1);
        trs =  translation_ * rotation_ * scale_;
    }

}