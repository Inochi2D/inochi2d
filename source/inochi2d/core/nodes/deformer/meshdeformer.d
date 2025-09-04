/**
    Inochi2D Mesh Deformer Node

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen, seagetch
*/
module inochi2d.core.nodes.deformer.meshdeformer;
import inochi2d.core.nodes.deformer;
import inochi2d.core.nodes.drawable;
import inochi2d.core.math;
import inochi2d.core;
import std.exception;
import std.typecons: tuple, Tuple;
import std.stdio;

/**
    A deformer which deforms child nodes stored within it,

*/
@TypeId("MeshGroup")
class MeshDeformer : Deformer {
private:
    ushort[] bitMask;
    vec4 bounds;
    Triangle[] triangles;
    vec2[] transformedVertices = [];
    mat4 forwardMatrix;
    mat4 inverseMatrix;
    bool translateChildren = true;
    bool precalculated = false;

    vec2[] deformed_;
protected:
    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void onSerialize(ref JSONValue object, bool recursive=true) {
        super.onSerialize(object, recursive);

        MeshData data = mesh.toMeshData();
        object["mesh"] = data.serialize();
    }

    override
    void onDeserialize(ref JSONValue object) {
        super.onDeserialize(object);

        this.mesh = Mesh.fromMeshData(object.tryGet!MeshData("mesh"));
        this.deformed_ = mesh.points.dup;
    }
public:

    /**
        The mesh
    */
    Mesh mesh;

    /**
        Constructs a new MeshGroup node
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        The control points of the deformer.
    */
    override @property vec2[] controlPoints() => deformed_;
    override @property void controlPoints(vec2[] value) {
        import nulib.math : min;

        size_t m = min(value.length, deformed_.length);
        deformed_[0..m] = value[0..m];
    }

    /**
        The points which may be deformed by the deformer.
    */
    override void deform(vec2[] deformed, bool absolute) {
        super.deform(deformed, absolute);
    }

    /**
        Resets the deformation for the IDeformable.
    */
    override void resetDeform() {
        deformed_[0..$] = this.mesh.points[0..$];
    }

//     Tuple!(vec2[], mat4*) filterChildren(vec2[] origVertices, vec2[] origDeformation, mat4* origTransform) {
//         if (!precalculated)
//             return Tuple!(vec2[], mat4*)(null, null);

//         mat4 centerMatrix = inverseMatrix * (*origTransform);

//         // Transform children vertices in MeshGroup coordinates.
//         auto r = rect(bounds.x, bounds.y, (ceil(bounds.z) - floor(bounds.x) + 1), (ceil(bounds.w) - floor(bounds.y) + 1));
//         foreach(i, vertex; origVertices) {
//             vec2 cVertex;
//             cVertex = vec2(centerMatrix * vec4(vertex+origDeformation[i], 0, 1));

//             int index = -1;
//             if (bounds.x <= cVertex.x && cVertex.x < bounds.z && bounds.y <= cVertex.y && cVertex.y < bounds.w) {
//                 ushort bit = bitMask[cast(int)(cVertex.y - bounds.y) * cast(int)r.width + cast(int)(cVertex.x - bounds.x)];
//                 index = bit - 1;
//             }
//             vec2 newPos = (index < 0)? cVertex: (triangles[index].transformMatrix * vec3(cVertex, 1)).xy;
//             origDeformation[i] = newPos - origVertices[i];
//         }
//         return tuple(origDeformation, &forwardMatrix);
//     }

//     /**
//         A list of the shape offsets to apply per part
//     */
//     override
//     void update() {
//         if (deformPoints.length > 0) {
//             transformedVertices.length = vertices.length;
//             foreach(i, vertex; vertices) {
//                 transformedVertices[i] = vertex+this.deformation[i];
//             }
//             foreach (index; 0..triangles.length) {
//                 auto p1 = transformedVertices[data.indices[index * 3]];
//                 auto p2 = transformedVertices[data.indices[index * 3 + 1]];
//                 auto p3 = transformedVertices[data.indices[index * 3 + 2]];
//                 triangles[index].transformMatrix = mat3([p2.x - p1.x, p3.x - p1.x, p1.x,
//                                                         p2.y - p1.y, p3.y - p1.y, p1.y,
//                                                         0, 0, 1]) * triangles[index].offsetMatrices;
//             }
//             forwardMatrix = transform.matrix;
//             inverseMatrix = globalTransform.matrix.inverse;
//         }

//         Node.update();
//         this.updateDeform();
//    }

//     override
//     void onSerialize(ref JSONValue object, bool recursive = true) {
//         super.onSerialize(object, recursive);

//         object["dynamic_deformation"] = dynamic;
//         object["translate_children"] = translateChildren;
//     }

//     override
//     void onDeserialize(ref JSONValue object) {
//         super.onDeserialize(object);

//         object.tryGetRef(dynamic, "dynamic_deformation");
//         object.tryGetRef(translateChildren, "translate_children");
//     }

//     override
//     void setupChild(Node child) {
 
//         void setGroup(Node node) {
//             auto drawable = cast(Drawable)node;
//             auto group    = cast(MeshGroup)node;
//             auto composite = cast(Composite)node;
//             bool isDrawable = drawable !is null;
//             bool isComposite = composite !is null && composite.propagateMeshGroup;
//             bool mustPropagate = (isDrawable && group is null) || isComposite;
//             if (translateChildren || isDrawable) {
//                 if (isDrawable && dynamic) {
//                     node.preProcessFilter  = null;
//                     node.postProcessFilter = &filterChildren;
//                 } else {
//                     node.preProcessFilter  = &filterChildren;
//                     node.postProcessFilter = null;
//                 }
//             } else {
//                 node.preProcessFilter  = null;
//                 node.postProcessFilter = null;
//             }
//             // traverse children if node is Drawable and is not MeshGroup instance.
//             if (mustPropagate) {
//                 foreach (child; node.children) {
//                     setGroup(child);
//                 }
//             }
//         }

//         if (data.indices.length > 0) {
//             setGroup(child);
//         } 

//     }

//     void applyDeformToChildren(Parameter[] params) {
//         if (dynamic || data.indices.length == 0)
//             return;

//         if (!precalculated) {
//             precalculate();
//         }
//         forwardMatrix = transform.matrix;
//         inverseMatrix = globalTransform.matrix.inverse;

//         foreach (param; params) {
//             void transferChildren(Node node, int x, int y) {
//                 auto drawable = cast(Drawable)node;
//                 auto group = cast(MeshDeformer)node;
//                 auto composite = cast(Composite)node;
//                 bool isDrawable = drawable !is null;
//                 bool isComposite = composite !is null && composite.propagateMeshGroup;
//                 bool mustPropagate = (isDrawable && group is null) || isComposite;
//                 if (isDrawable) {
//                     auto vertices = drawable.vertices;
//                     mat4 matrix = drawable.transform.matrix;

//                     auto nodeBinding = cast(DeformationParameterBinding)param.getOrAddBinding(node, "deform");
//                     auto nodeDeform = nodeBinding.values[x][y].vertexOffsets[].dup;
//                     Tuple!(vec2[], mat4*) filterResult = filterChildren(vertices, nodeDeform, &matrix);
//                     if (filterResult[0] !is null) {
//                         nodeBinding.values[x][y].vertexOffsets[0..filterResult[0].length] = filterResult[0][0..$];
//                         nodeBinding.getIsSet()[x][y] = true;
//                     }
//                 } else if (translateChildren && !isComposite) {
//                     auto vertices = [node.localTransform.translation.xy];
//                     mat4 matrix = node.parent? node.parent.transform.matrix: mat4.identity;

//                     auto nodeBindingX = cast(ValueParameterBinding)param.getOrAddBinding(node, "transform.t.x");
//                     auto nodeBindingY = cast(ValueParameterBinding)param.getOrAddBinding(node, "transform.t.y");
//                     auto nodeDeform = [node.offsetTransform.translation.xy];
//                     Tuple!(vec2[], mat4*) filterResult = filterChildren(vertices, nodeDeform, &matrix);
//                     if (filterResult[0] !is null) {
//                         nodeBindingX.values[x][y] += filterResult[0][0].x;
//                         nodeBindingY.values[x][y] += filterResult[0][0].y;
//                         nodeBindingX.getIsSet()[x][y] = true;
//                         nodeBindingY.getIsSet()[x][y] = true;
//                     }

//                 }
//                 if (mustPropagate) {
//                     foreach (child; node.children) {
//                         transferChildren(child, x, y);
//                     }
//                 }
//             }


//             if  (auto binding = param.getBinding(this, "deform")) {
//                 auto deformBinding = cast(DeformationParameterBinding)binding;
//                 assert(deformBinding !is null);
//                 Node target = binding.getTarget().node;

//                 for (int x = 0; x < param.axisPoints[0].length; x ++) {
//                     for (int y = 0; y < param.axisPoints[1].length; y ++) {

//                         vec2[] deformation;
//                         if (deformBinding.isSet_[x][y])
//                             deformation = deformBinding.values[x][y].vertexOffsets[].dup;
//                         else {
//                             bool rightMost  = x == param.axisPoints[0].length - 1;
//                             bool bottomMost = y == param.axisPoints[1].length - 1;
//                             deformation = deformBinding.interpolate(vec2u(rightMost? x - 1: x, bottomMost? y - 1: y), vec2(rightMost? 1: 0, bottomMost? 1:0)).vertexOffsets[];
//                         }
//                         transformedVertices.length = vertices.length;
//                         foreach(i, vertex; vertices) {
//                             transformedVertices[i] = vertex + deformation[i];
//                         }
//                         foreach (index; 0..triangles.length) {
//                             auto p1 = transformedVertices[data.indices[index * 3]];
//                             auto p2 = transformedVertices[data.indices[index * 3 + 1]];
//                             auto p3 = transformedVertices[data.indices[index * 3 + 2]];
//                             triangles[index].transformMatrix = mat3([p2.x - p1.x, p3.x - p1.x, p1.x,
//                                                                     p2.y - p1.y, p3.y - p1.y, p1.y,
//                                                                     0, 0, 1]) * triangles[index].offsetMatrices;
//                         }

//                         foreach (child; children) {
//                             transferChildren(child, x, y);
//                         }

//                     }
//                 }
//                 param.removeBinding(binding);
//             }

//         }
//         data.indices.length = 0;
//         data.vertices.length = 0;
//         data.uvs.length = 0;
//         rebuffer(data);
//         translateChildren = false;
//         precalculated = false;
//     }

//     void switchMode(bool dynamic) {
//         if (this.dynamic != dynamic) {
//             this.dynamic = dynamic;
//             precalculated = false;
//         }
//     }

//     bool getTranslateChildren() { return translateChildren; }

//     void setTranslateChildren(bool value) {
//         translateChildren = value;
//         foreach (child; children)
//             setupChild(child);
//     }

//     void clearCache() {
//         precalculated = false;
//         bitMask.length = 0;
//         triangles.length = 0;
//     }

    override
    string typeId() { return "MeshGroup"; }
}

//
//          IMPLEMENTATION DETAILS
//
private:

struct Triangle {
    mat3 offsetMatrices;
    mat3 transformMatrix;
}