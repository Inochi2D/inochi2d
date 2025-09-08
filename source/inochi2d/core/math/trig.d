/**
    Inochi2D Triangles and trigonometry

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.math.trig;
import inmath.linalg;

/**
    A 2D triangle
*/
struct Triangle {
@nogc:
    vec2 p1;
    vec2 p2;
    vec2 p3;

    /**
        Gets the barycentric coordinates of the given point.

        Params:
            pt = The point to check.

        Returns:
            The barycentric coordinates in relation to each
            vertex of the triangle.
    */
    pragma(inline, true)
    vec3 barycentric(vec2 pt) nothrow pure {
        vec2 v1 = p2 - p1;
        vec2 v2 = p3 - p1;
        vec2 v3 = pt - p1;
        float den = v1.x * v2.y - v2.x * v1.y;
        float v = (v3.x * v2.y - v2.x * v3.y) / den;
        float w = (v1.x * v3.y - v3.x * v1.y) / den;
        return vec3(
            1.0 - v - w,
            v,
            w,
        );
    }

    /**
        Whether the triangle contains the given point.

        Params:
            pt = The point to check.
        
        Returns:
            $(D true) if the given point lies within this
            triangle, $(D false) otherwise.
    */
    pragma(inline, true)
    bool contains(vec2 pt) nothrow pure {
        float d1 = sign(pt, p1, p2);
        float d2 = sign(pt, p2, p3);
        float d3 = sign(pt, p3, p1);
        return !(
            ((d1 < 0) || (d2 < 0) || (d3 < 0)) &&
            ((d1 > 0) || (d2 > 0) || (d3 > 0))
        );
    }
}

/**
    Gets the sign between 3 points.

    Params:
        p1 = The first point
        p2 = The second point
        p3 = The third point.
    
    Returns:
        A float determining the sign between p1, p2 and p3.
*/
pragma(inline, true)
float sign (ref vec2 p1, ref vec2 p2, ref vec2 p3) @nogc nothrow pure {
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
}