/*
    Inochi2D MeshGroup Node

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.meshgroup;
import inochi2d.core.nodes.drawable;
import inochi2d.integration;
import inochi2d.fmt.serialize;
import inochi2d.math;
import inochi2d.math.triangle;
import std.exception;
import inochi2d.core.dbg;
import inochi2d.core;


package(inochi2d) {
    void inInitMeshGroup() {
        inRegisterNodeType!MeshGroup;
    }
}


private {
struct Triangle{
    vec2[3] vertices;
    mat3[6] offsetMatrices;
    vec2[2][6] axes;
    float[2] axeslen;
}
}

/**
    Contains various deformation shapes that can be applied to
    children of this node
*/
@TypeId("MeshGroup")
class MeshGroup : Drawable {
protected:
    ushort[] bitMask;
    vec4 bounds;
    Triangle[] triangles;

    override
    string typeId() { return "MeshGroup"; }
    
public:
    /**
        Constructs a new MeshGroup node
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        A list of the shape offsets to apply per part
    */


    override
    void update() {
        super.update();
    }

    override
    void draw() {
        super.draw();
    }


    override
    void precalculate() {
        vec4 getBounds(T)(ref T vertices) {
            vec4 bounds = vec4(float.max, float.max, float.min_normal, float.min_normal);
            foreach (v; vertices) {
                bounds = vec4(min(bounds.x, v.x), min(bounds.y, v.y), max(bounds.z, v.x), max(bounds.w, v.y));
            }
            return bounds;
        }

        // Calculating conversion matrix for triangles
        bounds = getBounds(data.vertices);
        foreach (i; 0..data.indices.length / 3) {
            Triangle t;
            t.vertices = [
                data.vertices[data.indices[3*i]],
                data.vertices[data.indices[3*i+1]],
                data.vertices[data.indices[3*i+2]]
            ];
            
            foreach (a; 0..3) {
                foreach (b; 1..3) {
                    int i1 = a;
                    int i2 = (a + b) % 3;
                    int i3 = (a + 3 - b) % 3;
                    int vindex = 2 * a + (b - 1);
                    vec2* p1 = &t.vertices[i1];
                    vec2* p2 = &t.vertices[i2];
                    vec2* p3 = &t.vertices[i3];

                    vec2 axis0 = *p2 - *p1;
                    t.axeslen[0] = axis0.length;
                    axis0 /= t.axeslen[0];
                    vec2 axis1 = *p3 - *p1;
                    t.axeslen[1] = axis1.length;
                    axis1 /= t.axeslen[1];

                    vec3 raxis1 = mat3([axis0.x, axis0.y, 0, -axis0.y, axis0.x, 0, 0, 0, 1]) * vec3(axis1, 1);
                    float cosA = raxis1.x;
                    float sinA = raxis1.y;
                    t.offsetMatrices[vindex] = 
                        mat3([1, -cosA/sinA, 0, 
                              0, 1/sinA, 0, 
                              0, 0, 1]) * 
                        mat3([axis0.x, axis0.y, 0, 
                              -axis0.y, axis0.x, 0, 
                              0, 0, 1]) * 
                        mat3([1, 0, -(p1).x, 
                              0, 1, -(p1).y, 
                              0, 0, 1]);
                    t.axes[vindex][0] = axis0;
                    t.axes[vindex][1] = axis1;
                }
            }
            triangles ~= t;
        }

        // Construct bitMap
        int width  = cast(int)(ceil(bounds.z) - floor(bounds.x) + 1);
        int height = cast(int)(ceil(bounds.w) - floor(bounds.y) + 1);
        bitMask.length = width * height;
        foreach (size_t i, t; triangles) {
            vec4 tbounds = getBounds(t.vertices);
            int bwidth  = cast(int)(ceil(tbounds.z) - floor(tbounds.x) + 1);
            int bheight = cast(int)(ceil(tbounds.w) - floor(tbounds.y) + 1);
            int top  = cast(int)floor(tbounds.y);
            int left = cast(int)floor(tbounds.x);
            foreach (y; 0..bheight) {
                foreach (x; 0..bwidth) {
                    vec2 pt = vec2(left + x, top + y);
                    if (isPointInTriangle(pt, t.vertices)) {
                        int vindex = 0;
                        ushort id = cast(ushort)((i + 1) << 3 | vindex);
                        bitMask[cast(int)(pt.y * width + pt.x)] = id;
                    } else {
                        bitMask[cast(int)(pt.y * width + pt.x)] = 0;
                    }
                }
            }

        }

    }


    override
    void postProcessVertex() {
        foreach (c; children) {
            c.postProcessVertex();
        }

    }


    override
    void renderMask(bool dodge = false) {

    }


    override
    void serializeSelf(ref InochiSerializer serializer) {
        super.serializeSelf(serializer);
    }

    override
    SerdeException deserializeFromFghj(Fghj data) {
        return super.deserializeFromFghj(data);
    }


}