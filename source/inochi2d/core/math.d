/**
    Inochi2D Math Primitives

    Copyright: 
        Copyright © 2020-2025, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)

    Authors:
        Luna Nielsen
        Asahi Lina
*/
module inochi2d.core.math;
import inochi2d.fmt.serde;
import inochi2d.core.meshdata;
import inochi2d.core;
public import inmath.linalg;
public import inmath.util;
public import inmath.dampen;
public import inmath.math;
public import inmath.interpolate;
public import std.math : isFinite;
import std.algorithm;
import std.json;

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
        Rotation of the camera
    */
    float rotation = 0f;

    /**
        Size of the camera
    */
    vec2 scale = vec2(1, 1);

    /**
        Gets the real size of the camera
    */
    @property vec2 realSize() {
        int width, height;
        inGetViewport(width, height);

        return vec2(cast(float)width/scale.x, cast(float)height/scale.y);
    }

    deprecated("Use Camera.realSize instead.")
    alias getRealSize = realSize;

    /**
        Gets the center offset of the camera
    */
    @property vec2 centerOffset() {
        vec2 realSize = realSize();
        return realSize/2;
    }

    deprecated("Use Camera.centerOffset instead.")
    alias getCenterOffset = centerOffset;

    /**
        Matrix for this camera
    */
    @property mat4 matrix() {
        if(!position.isFinite) position = vec2(0);
        if(!scale.isFinite) scale = vec2(1);
        if(!rotation.isFinite) rotation = 0;

        vec2 realSize_ = this.realSize;
        if(!realSize_.isFinite) return mat4.identity;
        
        vec2 origin = vec2(realSize_.x/2, realSize_.y/2);
        vec3 pos = vec3(position.x, position.y, -(ushort.max/2));

        return 
            mat4.orthographic(0f, realSize.x, realSize.y, 0, 0, ushort.max) * 
            mat4.translation(origin.x, origin.y, 0) *
            mat4.zRotation(rotation) *
            mat4.translation(pos);
    }
}

/**
    A transform
*/
struct Transform {
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
        Calculates offset to other vector.
    */
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
        return tnew;
    }

    /**
        Gets the matrix for this transform
    */
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

    /**
        Clears the vector
    */
    void clear() {
        translation = vec3(0);
        rotation = vec3(0);
        scale = vec2(1, 1);
    }

    /**
        Gets a string representation of the transform.
    */
    string toString() const {
        import std.format : format;
        return "%s, %s, %s".format(translation.toString, rotation.toString, scale.toString);
    }

    /**
        Serializes the transform.
    */
    void onSerialize(ref JSONValue object) {
        object["trans"] = translation.serialize();
        object["rot"] = rotation.serialize();
        object["scale"] = scale.serialize();
    }

    /**
        Deserializes a transform from JSON.
    */
    void onDeserialize(ref JSONValue object) {
        object.tryGetRef(translation, "trans");
        object.tryGetRef(rotation, "rot");
        object.tryGetRef(scale, "scale");
    }
    
    // NOTE:    This private var is declared here to allow instantiating
    //          the Transform like prior, but with the added benefit of
    //          being able to do so with the new auto-generated constructors.
private:
    mat4 trs = mat4.identity;
}


bool isPointInTriangle(vec2 pt, vec2[3] triangle) {
    float sign (ref vec2 p1, ref vec2 p2, ref vec2 p3) {
        return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
    }
    vec2 p1 = triangle[0];
    vec2 p2 = triangle[1];
    vec2 p3 = triangle[2];

    auto d1 = sign(pt, p1, p2);
    auto d2 = sign(pt, p2, p3);
    auto d3 = sign(pt, p3, p1);

    auto hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
    auto hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);

    return !(hasNeg && hasPos);
}


int[] findSurroundingTriangle(vec2 pt, ref MeshData bindingMesh) {
    bool isPointInTriangle(vec2 pt, int[] triangle) {
        float sign (ref vec2 p1, ref vec2 p2, ref vec2 p3) {
            return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
        }
        vec2 p1 = bindingMesh.vertices[triangle[0]];
        vec2 p2 = bindingMesh.vertices[triangle[1]];
        vec2 p3 = bindingMesh.vertices[triangle[2]];

        auto d1 = sign(pt, p1, p2);
        auto d2 = sign(pt, p2, p3);
        auto d3 = sign(pt, p3, p1);

        auto hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
        auto hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);

        return !(hasNeg && hasPos);
    }
    int i = 0;
    int[] triangle = [0, 1, 2];
    while (i < bindingMesh.indices.length) {
        triangle[0] = bindingMesh.indices[i];
        triangle[1] = bindingMesh.indices[i+1];
        triangle[2] = bindingMesh.indices[i+2];
        if (isPointInTriangle(pt, triangle)) {
            return triangle;
        }
        i += 3;
    }
    return null;
}


// Calculate offset of point in coordinates of triangle.
vec2 calcOffsetInTriangleCoords(vec2 pt, ref MeshData bindingMesh, ref int[] triangle) {
    if ((pt - bindingMesh.vertices[triangle[0]]).lengthSquared > 
        (pt - bindingMesh.vertices[triangle[1]]).lengthSquared) {
        swap(triangle[0], triangle[1]);
    }
    if ((pt - bindingMesh.vertices[triangle[0]]).lengthSquared > 
        (pt - bindingMesh.vertices[triangle[2]]).lengthSquared) {
        swap(triangle[0], triangle[2]);
    }
    auto p1 = bindingMesh.vertices[triangle[0]];
    auto p2 = bindingMesh.vertices[triangle[1]];
    auto p3 = bindingMesh.vertices[triangle[2]];
    vec2 axis0 = p2 - p1;
    float axis0len = axis0.length;
    axis0 /= axis0.length;
    vec2 axis1 = p3 - p1;
    float axis1len = axis1.length;
    axis1 /= axis1.length;

    auto relPt = pt - p1;
    if (relPt.lengthSquared == 0)
        return vec2(0, 0);
    float cosA = dot(axis0, axis1);
    if (cosA == 0) {
        return vec2(dot(relPt, axis0), dot(relPt, axis1));
    } else {
        float argA = acos(cosA);
        float sinA = sin(argA);
        float tanA = tan(argA);
        float cosB = dot(axis0, relPt) / relPt.length;
        float argB = acos(cosB);
        float sinB = sin(argB);
        
        vec2 ortPt = vec2(relPt.length * cosB, relPt.length * sinB);
        
        mat2 H = mat2([1, -1/tanA, 0, 1/sinA]);
        auto result = H * ortPt;

        return result;
    }
}

// Unsigned short vectors
alias vec2us = Vector!(ushort, 2); /// ditto
alias vec3us = Vector!(ushort, 3); /// ditto
alias vec4us = Vector!(ushort, 4); /// ditto

/**
    Serializes a provided vector type.

    Params:
        value = The vector to serialize
        dst =   The destination JSON value
    
    Returns:
        The serialized vector
*/
void onSerialize(T)(ref T value, ref JSONValue dst)
if(isVector!T) {
    dst = JSONValue.emptyArray;
    static foreach(i; 0..T.dimension) {
        dst.array ~= JSONValue(isFinite(value.vector[i]) ? value.vector[i] : 0);
    }
}

/**
    Gets whether a point is within an axis aligned rectangle
*/
bool contains(vec4 a, vec2 b) {
    return  b.x >= a.x && 
            b.y >= a.y &&
            b.x <= a.x+a.z &&
            b.y <= a.y+a.w;
}

/**
    Checks if 2 lines segments are intersecting
*/
bool areLineSegmentsIntersecting(vec2 p1, vec2 p2, vec2 p3, vec2 p4) {
    float epsilon = 0.00001f;
    float demoninator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y);
    if (demoninator == 0) return false;

    float uA = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / demoninator;
    float uB = ((p2.x - p1.x) * (p1.y - p3.y) - (p2.y - p1.y) * (p1.x - p3.x)) / demoninator;
    return (uA > 0+epsilon && uA < 1-epsilon && uB > 0+epsilon && uB < 1-epsilon);
}
