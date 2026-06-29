/**
    Transforms

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.math.transform;
import inochi2d.core.math;
import inochi2d.core;
import numath;

/**
    A transform
*/
struct Transform {
public:
@nogc:

    /**
        The translation of the transform
    */
    vec3 translation = vec3(0, 0, 0);

    /**
        The rotation of the transform
    */
    vec3 rotation = vec3(0, 0, 0); //; = quat.identity;

    /**
        The scale of the transform
    */
    vec2 scale = vec2(1, 1);

    /**
        Returns the result of 2 transforms multiplied together
    */
    Transform opBinaryRight(string op : "+")(Transform other) @nogc {
        Transform tnew;
        tnew.translation = this.translation + other.translation;
        tnew.rotation = this.rotation + other.rotation;
        tnew.scale = this.scale * other.scale;
        return tnew;
    }

    /**
        Calculates the basis matrix for this transform.
    */
    Basis matrix() {
        return Basis(
            mat4.translation(this.translation) *
            mat4.zRotation(this.rotation.z) * mat4.yRotation(this.rotation.y) * mat4.xRotation(this.rotation.x) *
            mat4.scaling(this.scale.x, this.scale.y, 1)
        );
    }

    /**
        Clears the vector
    */
    void clear() {
        translation = vec3(0);
        rotation = vec3(0);
        scale = vec2(1, 1);
    }

    /**
        Serializes the transform.
    */
    void onSerialize(ref DataNode object) {
        object["trans"] = translation.data.serialize();
        object["rot"] = rotation.data.serialize();
        object["scale"] = scale.data.serialize();
    }

    /**
        Deserializes a transform from JSON.
    */
    void onDeserialize(ref DataNode object) {
        object.tryGetRef(translation.data, "trans", [0, 0, 0]);
        object.tryGetRef(rotation.data, "rot", [0, 0, 0]);
        object.tryGetRef(scale.data, "scale", [1, 1]);
    }
}

/**
    A 4x4 basis matrix.
*/
struct Basis {
public:
@nogc:

    /**
        The underlying matrix of the basis
    */
    mat4 matrix;
    alias matrix this;

    /**
        The translation of the basis.
    */
    @property vec3 translation() pure => vec3(matrix.matrix[0][3], matrix.matrix[1][3], matrix.matrix[2][3]);
}