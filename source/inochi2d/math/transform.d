/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors:
        Luna Nielsen
        Asahi Lina
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

    Transform calcOffset(Transform other) {
        Transform tnew;

        tnew.translation = this.translation+other.translation;
        tnew.rotation = this.rotation+other.rotation;
        tnew.scale = this.scale*other.scale;
        tnew.update();

        return tnew;
    }

    /**
        Returns the result of 2 transforms multiplied together
    */
    Transform opBinary(string op : "*")(Transform other) {
        Transform tnew;

        mat4 strs = other.trs * this.trs;
        
        // TRANSLATION
        tnew.translation = vec3(strs * vec4(1, 1, 1, 1));
        
        // ROTATION
        tnew.rotation = this.rotation+other.rotation;
        
        // SCALE
        tnew.scale = this.scale*other.scale;
        tnew.trs = strs;
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
        trs = 
            mat4.translation(this.translation) *
            quat.eulerRotation(this.rotation.x, this.rotation.y, this.rotation.z).toMatrix!(4, 4) *
            mat4.scaling(this.scale.x, this.scale.y, 1);
    }

    void clear() {
        translation = vec3(0);
        rotation = vec3(0);
        scale = vec2(1, 1);
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

            serializer.putKey("rot");
            rotation.serialize(serializer);

            serializer.putKey("scale");
            scale.serialize(serializer);

        serializer.objectEnd(state);
    }

    SerdeException deserializeFromFghj(Fghj data) {
        translation.deserialize(data["trans"]);
        rotation.deserialize(data["rot"]);
        scale.deserialize(data["scale"]);
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
        mat3 rotation_ = mat3.zRotation(rotation);
        mat3 scale_ = mat3.scaling(scale.x, scale.y, 1);
        trs =  translation_ * rotation_ * scale_;
    }

}