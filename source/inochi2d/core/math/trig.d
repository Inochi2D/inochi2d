/**
    Inochi2D Triangles and trigonometry

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.math.trig;
import numath;

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
float sign(ref vec2 p1, ref vec2 p2, ref vec2 p3) @nogc nothrow pure {
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
}

/**
    Finds the closest 2 points to the given point.

    Param:
        point = The point to find the closest 2 points to
        mesh =  The mesh to index.

    Returns:
        The vertex indices of the mesh of the 2 closest points
        to the given point, or $(D -1) if there's fewer than 2
        points in the mesh.
*/
ptrdiff_t[2] findClosest2(inout(vec2) point, inout(vec2)[] mesh) @nogc nothrow pure {
    ptrdiff_t p1 = -1;
    ptrdiff_t p2 = -1;
    float closestDist = float.max;
    foreach(i, p; mesh) {
        if (p.distance(point) < closestDist) {
            p2 = p1;
            p1 = i;
        }
    }
    return [p1, p2];
}

/**
    Finds the closest point to the given point.

    Param:
        point = The point to find the closest point to
        mesh =  The mesh to index.

    Returns:
        The vertex index of the closest point,
        or $(D -1) if there is no points in the mesh.
*/
ptrdiff_t findClosest(inout(vec2) point, inout(vec2)[] mesh) @nogc nothrow pure {
    ptrdiff_t p1 = -1;
    float closestDist = float.max;
    foreach(i, p; mesh) {
        if (p.distance(point) < closestDist) {
            p1 = i;
        }
    }
    return p1;
}