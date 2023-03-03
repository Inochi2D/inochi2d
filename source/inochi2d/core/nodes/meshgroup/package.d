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
import std.stdio;

package(inochi2d) {
    void inInitMeshGroup() {
        inRegisterNodeType!MeshGroup;
    }
}


private {
struct Triangle{
    mat3 offsetMatrices;
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
    bool dynamic = false;

    /**
        Constructs a new MeshGroup node
    */
    this(Node parent = null) {
        super(parent);
    }

    Tuple!(vec2[], mat4*) filterChildren(vec2[] origVertices, vec2[] origDeformation, mat4* origTransform) {
        if (!precalculated)
            return Tuple!(vec2[], mat4*)(null, null);

        mat4 centerMatrix = inverseMatrix * (*origTransform);
        writefln("dynamic=%d", dynamic);

        // Transform children vertices in MeshGroup coordinates.
        auto r = rect(bounds.x, bounds.y, (ceil(bounds.z) - floor(bounds.x) + 1), (ceil(bounds.w) - floor(bounds.y) + 1));
        foreach(i, vertex; origVertices) {
            vec2 cVertex;
            if (dynamic)
                cVertex = vec2(centerMatrix * vec4(vertex+origDeformation[i], 0, 1));
            else
                cVertex = vec2(centerMatrix * vec4(vertex, 0, 1));
            int index = -1;
            if (bounds.x <= cVertex.x && cVertex.x < bounds.z && bounds.y <= cVertex.y && cVertex.y < bounds.w) {
                ushort bit = bitMask[cast(int)(cVertex.y - bounds.y) * cast(int)r.width + cast(int)(cVertex.x - bounds.x)];
                index = bit - 1;
            }
            vec2 newPos = (index < 0)? cVertex: (triangles[index].transformMatrix * vec3(cVertex, 1)).xy;
            if (dynamic)
                origDeformation[i] = newPos - origVertices[i];
            else
                origDeformation[i] += newPos - cVertex;
        }

        if (dynamic)
            return tuple(origDeformation, &forwardMatrix);
        else
            return tuple(origDeformation, cast(mat4*)null);
    }

    /**
        A list of the shape offsets to apply per part
    */
    override
    void update() {
        if (data.indices.length > 0) {
            if (!precalculated) {
                precalculate();
            }
            transformedVertices.length = vertices.length;
            foreach(i, vertex; vertices) {
                if (dynamic)
                    transformedVertices[i] = vec2(this.localTransform.matrix * vec4(vertex+this.deformation[i], 0, 1));
                else
                    transformedVertices[i] = vec2(vec4(vertex+this.deformation[i], 0, 1));
            }
            foreach (index; 0..triangles.length) {
                auto p1 = transformedVertices[data.indices[index * 3]];
                auto p2 = transformedVertices[data.indices[index * 3 + 1]];
                auto p3 = transformedVertices[data.indices[index * 3 + 2]];
                triangles[index].transformMatrix = mat3([p2.x - p1.x, p3.x - p1.x, p1.x,
                                                        p2.y - p1.y, p3.y - p1.y, p1.y,
                                                        0, 0, 1]) * triangles[index].offsetMatrices;
            }
            forwardMatrix = transform.matrix;
            inverseMatrix = globalTransform.matrix.inverse;
        }

       super.update(); 
    }

    override
    void draw() {
        super.draw();
    }


    void precalculate() {
        if (data.indices.length == 0) {
            triangles.length = 0;
            bitMask.length   = 0;
            return;
        }

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
            vec2[3] tvertices = [
                data.vertices[data.indices[3*i]],
                data.vertices[data.indices[3*i+1]],
                data.vertices[data.indices[3*i+2]]
            ];
            
            vec2* p1 = &tvertices[0];
            vec2* p2 = &tvertices[1];
            vec2* p3 = &tvertices[2];

            vec2 axis0 = *p2 - *p1;
            float axis0len = axis0.length;
            axis0 /= axis0len;
            vec2 axis1 = *p3 - *p1;
            float axis1len = axis1.length;
            axis1 /= axis1len;

            vec3 raxis1 = mat3([axis0.x, axis0.y, 0, -axis0.y, axis0.x, 0, 0, 0, 1]) * vec3(axis1, 1);
            float cosA = raxis1.x;
            float sinA = raxis1.y;
            t.offsetMatrices = 
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
            triangles ~= t;
        }

        // Construct bitMap
        int width  = cast(int)(ceil(bounds.z) - floor(bounds.x) + 1);
        int height = cast(int)(ceil(bounds.w) - floor(bounds.y) + 1);
        bitMask.length = width * height;
        bitMask[] = 0;
        foreach (size_t i, t; triangles) {
            vec2[3] tvertices = [
                data.vertices[data.indices[3*i]],
                data.vertices[data.indices[3*i+1]],
                data.vertices[data.indices[3*i+2]]
            ];

            vec4 tbounds = getBounds(tvertices);
            int bwidth  = cast(int)(ceil(tbounds.z) - floor(tbounds.x) + 1);
            int bheight = cast(int)(ceil(tbounds.w) - floor(tbounds.y) + 1);
            int top  = cast(int)floor(tbounds.y);
            int left = cast(int)floor(tbounds.x);
            foreach (y; 0..bheight) {
                foreach (x; 0..bwidth) {
                    vec2 pt = vec2(left + x, top + y);
                    if (isPointInTriangle(pt, tvertices)) {
                        ushort id = cast(ushort)(i + 1);
                        pt-= bounds.xy;
                        bitMask[cast(int)(pt.y * width + pt.x)] = id;
                    }
                }
            }
        }

        precalculated = true;
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
        if (dynamic) {
            precalculated = false;
        }
    }

    override
    void serializeSelf(ref InochiSerializer serializer) {
        super.serializeSelf(serializer);

//        serializer.putKey("dynamic_deformation");
//        serializer.serializeValue(dynamic);

    }

    override
    SerdeException deserializeFromFghj(Fghj data) {
        super.deserializeFromFghj(data);

//        if (!data["dynamic_deformation"].isEmpty) 
//            data["dynamic_deformation"].deserializeValue(dynamic);
        return null;
    }

    override
    void setupChild(Node child) {
 
        void setGroup(Drawable drawable) {
            if (dynamic)
                drawable.postProcessFilter = &filterChildren;
            else
                drawable.preProcessFilter  = &filterChildren;
            auto group = cast(MeshGroup)drawable;
            if (group is null) {
                foreach (child; drawable.children) {
                    auto childDrawable = cast(Drawable)child;
                    if (childDrawable !is null)
                        setGroup(childDrawable);
                }
            }
        }

        if (data.indices.length > 0) {
            auto drawable = cast(Drawable)child;
            if (drawable !is null) {
                setGroup(drawable);
            }
        } 

    }

    void transfer(Parameter[] params) {
        if (dynamic || data.indices.length == 0)
            return;

        if (!precalculated) {
            precalculate();
        }
        forwardMatrix = transform.matrix;
        inverseMatrix = globalTransform.matrix.inverse;

        writefln("transfer: %s", name);

        foreach (param; params) {
            void transferChildren(Node node, int x, int y) {
                auto drawable = cast(Drawable)node;
                if (!drawable)
                    return;
                auto vertices = drawable.vertices;
                mat4 matrix = drawable.transform.matrix;
                auto nodeBinding = cast(DeformationParameterBinding)param.getOrAddBinding(node, "deform");
                auto nodeDeform = nodeBinding.values[x][y].vertexOffsets.dup;
                writefln("%s: vertices = %d", drawable.name, drawable.data.vertices.length);
                writefln("%s: nodeDeform: length =%d", drawable.name, nodeDeform.length);
                Tuple!(vec2[], mat4*) filterResult = filterChildren(vertices, nodeDeform, &matrix);
                if (filterResult[0] !is null) {
                    nodeBinding.values[x][y].vertexOffsets = filterResult[0];
                    writefln("new nodeDeform: length =%d", nodeBinding.values[x][y].vertexOffsets.length);
                }

                foreach (child; node.children) {
                    transferChildren(child, x, y);
                }
            }


            if  (auto binding = param.getBinding(this, "deform")) {
                auto deformBinding = cast(DeformationParameterBinding)binding;
                assert(deformBinding !is null);
                Node target = binding.getTarget().node;

                writefln("transfer.binding: %s", binding.getName());
                for (int x = 0; x < param.axisPoints[0].length; x ++) {
                    for (int y = 0; y < param.axisPoints[1].length; y ++) {

                        vec2[] deformation;
                        if (deformBinding.isSet_[x][y])
                            deformation = deformBinding.values[x][y].vertexOffsets;
                        else {
                            writef("x=%d, y=%d, index_x=%d", x, y, deformBinding.values.length);
                            writefln(", index_y=%d",deformBinding.values[x].length);
                            bool rightMost  = x == param.axisPoints[0].length - 1;
                            bool bottomMost = y == param.axisPoints[1].length - 1;
                            deformation = deformBinding.interpolate(vec2u(rightMost? x - 1: x, bottomMost? y - 1: y), vec2(rightMost? 1: 0, bottomMost? 1:0)).vertexOffsets;
                        }
                        transformedVertices.length = vertices.length;
                        foreach(i, vertex; vertices) {
                            transformedVertices[i] = vec2(vec4(vertex+deformation[i], 0, 1));
                        }
                        foreach (index; 0..triangles.length) {
                            auto p1 = transformedVertices[data.indices[index * 3]];
                            auto p2 = transformedVertices[data.indices[index * 3 + 1]];
                            auto p3 = transformedVertices[data.indices[index * 3 + 2]];
                            triangles[index].transformMatrix = mat3([p2.x - p1.x, p3.x - p1.x, p1.x,
                                                                    p2.y - p1.y, p3.y - p1.y, p1.y,
                                                                    0, 0, 1]) * triangles[index].offsetMatrices;
                        }

                        foreach (child; children) {
                            transferChildren(child, x, y);
                        }

                    }
                }
                param.removeBinding(binding);
                writefln("remove param for parameter %s, binding %s", param.name, binding.getName());
            }

        }
        data.indices.length = 0;
        data.vertices.length = 0;
        data.uvs.length = 0;
        rebuffer(data);
        precalculated = false;
    }
}