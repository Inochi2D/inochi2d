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
import std.typecons: tuple, Tuple;

package(inochi2d) {
    void inInitMeshGroup() {
        inRegisterNodeType!MeshGroup;
    }
}


private {
struct Triangle{
    vec2[3] vertices;
    mat3[6] offsetMatrices;
    mat3 transformMatrix;
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
    vec2[] transformedVertices = [];
    mat4 forwardMatrix;
    mat4 inverseMatrix;

    override
    string typeId() { return "MeshGroup"; }

    bool precalculated = false;
    
public:
    /**
        Constructs a new MeshGroup node
    */
    this(Node parent = null) {
        super(parent);
        precalculate();
    }

    Tuple!(vec2[], mat4*) filterChildren(vec2[] origVertices, vec2[] origDeformation, mat4* origTransform) {
        if (!precalculated)
            return Tuple!(vec2[], mat4*)(null, null);

        int findSurroundingTriangle(vec2 pt) {
            if (pt.x >= bounds.x && pt.x < bounds.z && pt.y >= bounds.y && pt.y < bounds.w) {
                int width  = cast(int)(ceil(bounds.z) - floor(bounds.x) + 1);
                ushort bit = bitMask[cast(int)(pt.y - bounds.y) * width + cast(int)(pt.x - bounds.x)];
                return (bit >> 3) - 1;
            } else {
                return -1;
            }
        }

        mat4 centerMatrix = inverseMatrix * (*origTransform);

        // Transform children vertices in MeshGroup coordinates.
        foreach(i, vertex; origVertices) {
            auto cVertex = vec2(centerMatrix * vec4(vertex+origDeformation[i], 0, 1));
            int index = findSurroundingTriangle(cVertex);
            vec2 newPos = (index < 0)? cVertex: (triangles[index].transformMatrix * vec3(cVertex, 1)).xy;
            origDeformation[i] = newPos - origVertices[i];
        }

        return tuple(origDeformation, &forwardMatrix);
    }

    /**
        A list of the shape offsets to apply per part
    */

    override
    void update() {
        if (!precalculated) {
            precalculate();
            precalculated = true;
        }
        transformedVertices.length = vertices.length;
        foreach(i, vertex; vertices) {
            transformedVertices[i] = vec2(this.localTransform.matrix * vec4(vertex+this.deformation[i], 0, 1));
        }
        foreach (index; 0..triangles.length) {
            auto p1 = transformedVertices[data.indices[index * 3]];
            auto p2 = transformedVertices[data.indices[index * 3 + 1]];
            auto p3 = transformedVertices[data.indices[index * 3 + 2]];
            triangles[index].transformMatrix = mat3([p2.x - p1.x, p3.x - p1.x, p1.x,
                                                     p2.y - p1.y, p3.y - p1.y, p1.y,
                                                     0, 0, 1]) * triangles[index].offsetMatrices[0];
        }
        forwardMatrix = transform.matrix;
        inverseMatrix = globalTransform.matrix.inverse;

       super.update(); 
    }

    override
    void draw() {
        super.draw();
    }


    void precalculate() {
        vec4 getBounds(T)(ref T vertices) {
            vec4 bounds = vec4(float.max, float.max, -float.max, -float.max);
            foreach (v; vertices) {
                bounds = vec4(min(bounds.x, v.x), min(bounds.y, v.y), max(bounds.z, v.x), max(bounds.w, v.y));
            }
            bounds.x = floor(bounds.x);
            bounds.y = floor(bounds.y);
            bounds.z = ceil(bounds.z);
            bounds.w = ceil(bounds.w);
            return bounds;
        }

        // Calculating conversion matrix for triangles
        bounds = getBounds(data.vertices);
        triangles.length = 0;
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
                    float axis0len = axis0.length;
                    axis0 /= axis0len;
                    vec2 axis1 = *p3 - *p1;
                    float axis1len = axis1.length;
                    axis1 /= axis1len;

                    vec3 raxis1 = mat3([axis0.x, axis0.y, 0, -axis0.y, axis0.x, 0, 0, 0, 1]) * vec3(axis1, 1);
                    float cosA = raxis1.x;
                    float sinA = raxis1.y;
                    t.offsetMatrices[vindex] = 
                        mat3([axis0len > 0? 1/axis0len: 0, 0, 0,
                              0, axis1len > 0? 1/axis1len: 0, 0,
                              0, 0, 1]) * 
                        mat3([1, -cosA/sinA, 0, 
                              0, 1/sinA, 0, 
                              0, 0, 1]) * 
                        mat3([axis0.x, axis0.y, 0, 
                              -axis0.y, axis0.x, 0, 
                              0, 0, 1]) * 
                        mat3([1, 0, -(p1).x, 
                              0, 1, -(p1).y, 
                              0, 0, 1]);
                }
            }
            triangles ~= t;
        }

        // Construct bitMap
        int width  = cast(int)(ceil(bounds.z) - floor(bounds.x) + 1);
        int height = cast(int)(ceil(bounds.w) - floor(bounds.y) + 1);
        bitMask.length = width * height;
        bitMask[] = 0;
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
                        pt-= bounds.xy;
                        bitMask[cast(int)(pt.y * width + pt.x)] = id;
                    }
                }
            }
        }

        foreach (child; children) {
            setupChild(child);
        }
    }

    override
    void renderMask(bool dodge = false) {

    }

    override
    void rebuffer(ref MeshData data) {
        super.rebuffer(data);
        precalculated = false;
    }

    override
    void serializeSelf(ref InochiSerializer serializer) {
        super.serializeSelf(serializer);
    }

    override
    SerdeException deserializeFromFghj(Fghj data) {
        return super.deserializeFromFghj(data);
    }

    override
    void setupChild(Node child) {
        void setGroup(Drawable drawable) {
            drawable.filter = &filterChildren;
            auto group = cast(MeshGroup)drawable;
            if (group is null) {
                foreach (child; drawable.children) {
                    auto childDrawable = cast(Drawable)child;
                    if (childDrawable !is null)
                        setGroup(childDrawable);
                }
            }
        } 
        auto drawable = cast(Drawable)child;
        if (drawable !is null) {
            setGroup(drawable);
        }

    }

}