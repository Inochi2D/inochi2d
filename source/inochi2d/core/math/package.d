/**
    Inochi2D Math Primitives

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
        Hoshino Lina
*/
module inochi2d.core.math;
import inochi2d.core;
import nulib.math;
import numem;

public import inochi2d.core.math.transform;
public import inochi2d.core.math.deform;
public import inochi2d.core.math.trig;
public import numath.dampen;
public import numath;

/**
    A camera
*/
abstract
class Camera : NuRefCounted {

    /**
        Size of the camera's viewport.
    */
    vec2 size = vec2(1, 1);

    /**
        The view-projection matrix for the camera.
    */
    abstract @property mat4 matrix() @nogc;

    /**
        Updates the state of the camera.
    */
    abstract void update() @nogc;
}

/**
    An orthographic camera
*/
class Camera2D : Camera {
private:
@nogc:
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
        Scale to apply to the camera's viewport.
    */
    float scale = 1;

    /**
        Gets the center offset of the camera
    */
    @property vec2 centerOffset() => size / 2.0;

    /**
        Matrix for this camera
    */
    override
    @property mat4 matrix() @nogc => projection;

    /**
        Updates the state of the camera.
    */
    override
    void update() @nogc {
        if (!position.isFinite)
            position = vec2(0);
        if (!scale.isFinite)
            scale = 1;
        if (!rotation.isFinite)
            rotation = 0;

        vec2 origin = vec2(size.x / 2, size.y / 2);
        vec3 pos = vec3(position.x, position.y, -(ushort.max/2));
        projection =
            mat4.orthographic(0f, size.x, size.y, 0, 0.001, ushort.max) *
            mat4.translation(origin.x, origin.y, 0) *
            mat4.scaling(scale, scale, 1) *
            mat4.zRotation(rotation) *
            mat4.translation(pos);
    }
}

/**
    Gets a relative vector between 2 matrices.

    Params:
        lhs = The left hand side matrix.
        rhs = The right hand side matrix.
    
    Returns:
        A vector describing the relative translation between
        the 2 matrices.
*/
vec3 relativeVectorTo(mat4 lhs, mat4 rhs) @nogc pure {
    mat4 cm = (lhs.inverse * rhs).translation;
    return vec3(cm.matrix[0][3], cm.matrix[1][3], cm.matrix[2][3]);
}

/**
    Gets a relative vector between 2 matrices, with the 
    multiplication-order of the left-hand and right-hand 
    side inverted.

    Params:
        lhs = The left hand side matrix.
        rhs = The right hand side matrix.
    
    Returns:
        A vector describing the relative translation between
        the 2 matrices.
*/
vec3 relativeVectorToInverse(mat4 lhs, mat4 rhs) @nogc pure {
    mat4 cm = (rhs * lhs.inverse).translation;
    return vec3(cm.matrix[0][3], cm.matrix[1][3], cm.matrix[2][3]);
}

int[] findSurroundingTriangle(vec2 pt, ref MeshData bindingMesh) {
    bool isPointInTriangle(vec2 pt, int[] triangle) {
        float sign(ref vec2 p1, ref vec2 p2, ref vec2 p3) {
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
        triangle[1] = bindingMesh.indices[i + 1];
        triangle[2] = bindingMesh.indices[i + 2];
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
        nu_swap(triangle[0], triangle[1]);
    }
    if ((pt - bindingMesh.vertices[triangle[0]]).lengthSquared >
            (pt - bindingMesh.vertices[triangle[2]]).lengthSquared) {
        nu_swap(triangle[0], triangle[2]);
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

        mat2 H = mat2([1, -1 / tanA, 0, 1 / sinA]);
        auto result = H * ortPt;

        return result;
    }
}

// Unsigned short vectors
alias vec2us = VectorImpl!(ushort, 2); /// ditto
alias vec3us = VectorImpl!(ushort, 3); /// ditto
alias vec4us = VectorImpl!(ushort, 4); /// ditto

/**
    Serializes a provided vector type.

    Params:
        value = The vector to serialize
        dst =   The destination JSON value
    
    Returns:
        The serialized vector
*/
void onSerialize(T)(ref T value, ref DataNode dst) @nogc if (isVector!T) {
    dst = DataNode.createArray();
    static foreach (i; 0 .. T.dimensions) {
        static if (__traits(isFloating, T)) {
            dst.array ~= DataNode(isFinite(value.data[i]) ? value.data[i] : 0);
        } else {
            dst.array ~= DataNode(value.data[i]);
        }
    }
}

/**
    Gets whether a point is within an axis aligned rectangle
*/
bool contains(vec4 a, vec2 b) {
    return b.x >= a.x &&
        b.y >= a.y &&
        b.x <= a.x + a.z &&
        b.y <= a.y + a.w;
}

/**
    Checks if 2 lines segments are intersecting
*/
bool areLineSegmentsIntersecting(vec2 p1, vec2 p2, vec2 p3, vec2 p4) {
    float epsilon = 0.00001f;
    float demoninator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y);
    if (demoninator == 0)
        return false;

    float uA = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / demoninator;
    float uB = ((p2.x - p1.x) * (p1.y - p3.y) - (p2.y - p1.y) * (p1.x - p3.x)) / demoninator;
    return (uA > 0 + epsilon && uA < 1 - epsilon && uB > 0 + epsilon && uB < 1 - epsilon);
}

/**
    Different modes of interpolation between values.
*/
enum InterpolateMode : uint {

    /**
        Round to nearest
    */
    nearest = 0,

    /**
        Linear interpolation
    */
    linear = 1,

    /**
        Round to nearest
    */
    stepped = 2,

    /**
        Interpolation using quadratic interpolation
    */
    quadratic = 3,

    /**
        Cubic interpolation
    */
    cubic = 4,
}

/**
    Converts a string key into a interpolation mode.
*/
InterpolateMode toInterpolateMode(string key) @nogc {
    switch (key) {

    case "nearest":
    case "Nearest":
        return InterpolateMode.nearest;

    case "linear":
    case "Linear":
        return InterpolateMode.linear;

    case "stepped":
    case "Stepped":
        return InterpolateMode.stepped;

    case "bezier":
    case "Bezier":
    case "quadratic":
        return InterpolateMode.quadratic;

    case "cubic":
    case "Cubic":
        return InterpolateMode.cubic;

    default:
        return InterpolateMode.linear;
    }
}
