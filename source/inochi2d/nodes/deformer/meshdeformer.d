/**
    Inochi2D Mesh Deformer Node

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
        seagetch
*/
module inochi2d.nodes.deformer.meshdeformer;
import inochi2d.nodes.deformer;
import inochi2d.nodes;
import inochi2d.common;
import inochi2d.core;
import nulib.string;
import numath.tri;
import numem;

import inochi2d.core.math.simd;
import inteli;

/**
    A deformer which deforms child nodes stored within it,
*/
@TypeId("MeshDeformer", IN_MAKE_TAG!(1, 2))  // Modern name
@TypeId("MeshGroup", IN_MAKE_TAG!(1, 2))  // Legacy name
class MeshDeformer : Deformer {
private:
    Mesh mesh_;
    DeformedMesh base_;
    DeformedMesh deformed_;
    MeshDeformerShape shape_;

protected:

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
    */
    override
    void onSerialize(ref DataNode object) @nogc {
        super.onSerialize(object);

        // NOTE:    MeshData is set up to free its contents on
        //          scope exit.
        MeshData data = MeshData(mesh);
        object["mesh"] = data.serialize();
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object =    The DataNode to deserialize from.
            state =     The state of the deserializer.
    */
    override
    void onDeserialize(ref DataNode object, ref ModelState state) @nogc {
        super.onDeserialize(object, state);

        this.deformed_ = nogc_new!DeformedMesh();
        this.base_ = nogc_new!DeformedMesh();
        auto meshData = object.tryGet!MeshData(state, "mesh");
        this.mesh = Mesh.fromMeshData(meshData);

        if (state.doUpgrade08 && !object.tryGet(state, "dynamic_deformation", false)) {
            state.warning(nstring(this.name[], " uses static deformation, this was removed in 0.9..."));
        }

        if (state.doUpgrade08 && object.tryGet(state, "translate_children", false)) {
            state.warning(nstring(this.name[], " translates its children via deformation, this was removed in 0.9..."));
        }
    }

    /**
        Called during the early update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onPreUpdate(DrawList drawList) @nogc {
        super.onPreUpdate(drawList);
        this.resetDeform();
    }

    /**
        Called during the update phase of a new frame.
        
        Params:
            delta =     Time since the last frame.
            drawList =  The drawlist for the active scene.
    */
    override
    void onUpdate(float delta, DrawList drawList) @nogc {
        base_.pushMatrix(this.deformBaseMatrix);
        deformed_.pushMatrix(this.deformBaseMatrix);

        super.onUpdate(delta, drawList);
    }

    /**
        Called during the late update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onPostUpdate(DrawList drawList) @nogc {
        super.onPostUpdate(drawList);

        // Not ready?
        if (!shape_.isReady) {
            super.onPostUpdate(drawList);
            return;
        }
        shape_.update(base_.points, deformed_.points);

        // Calculate the deltas from the world matrix.
        foreach (i, mesh; toDeform) {
            shape_.deformMesh(mesh);
        }
    }

    /**
        Called when the deformer's internal data should be
        rebuilt.
    */
    override
    void onRebuild() @nogc {
        super.onRebuild();
    }

public:

    /**
        The mesh
    */
    @property Mesh mesh() @nogc => mesh_;
    final @property void mesh(Mesh value) @nogc {
        if (value is mesh_)
            return;

        if (mesh_)
            mesh_.release();

        this.mesh_ = value.retained();
        this.shape_.setMesh(mesh_);

        this.base_.parent = value;
        this.deformed_.parent = value;

        this.base_.reset();
        this.base_.pushMatrix(this.deformBaseMatrix);
    }

    /**
        The underlying shape data of the deformer.
    */
    @property ref MeshDeformerShape shape() @nogc => shape_;

    /**
        The control points of the deformer.
    */
    override @property vec2[] controlPoints() @nogc => deformed_.points;
    override @property void controlPoints(vec2[] value) @nogc {
        import nulib.math : min;

        size_t m = min(value.length, deformed_.points.length);
        deformed_.points[0 .. m] = value[0 .. m];
    }

    /**
        The base position of the deformable's points, in world space.
    */
    override @property const(vec2)[] basePoints() @nogc => base_.points;

    /**
        The points which may be deformed by a deformer, in world space.
    */
    override @property vec2[] deformPoints() @nogc => deformed_.points;

    // Destructor
    ~this() {
        nogc_delete(shape_);
        nogc_delete(deformed_);
        nogc_delete(base_);
        mesh_.release();
    }

    /**
        Constructs a new MeshGroup node
    */
    this(Node parent = null) @nogc {
        super(parent);
    }

    /**
        Deforms the IDeformable.

        Params:
            deformed =  The deformation delta.
            absolute =  Whether the deformation is absolute,
                        replacing the original deformation.
    */
    override
    void deform(vec2[] deformed, bool absolute = false) @nogc {
        deformed_.deform(deformed);
    }

    /**
        Deforms a single vertex in the IDeformable

        Params:
            offset =    The offset into the point list to deform.
            deform =    The deformation delta.
            absolute =  Whether the deformation is absolute,
                        replacing the original deformation.
    */
    override
    void deform(size_t offset, vec2 deform, bool absolute = false) {
        deformed_.deform(offset, deform);
    }

    /**
        Resets the deformation for the IDeformable.
    */
    override
    void resetDeform() @nogc {
        deformed_.reset();
        base_.reset();
    }
}

mixin Register!(MeshDeformer, in_node_registry);

// TODO: Use a BVH to optimize lookups into the triangle list.

/**
    A mesh deformer triangle with metadata.
*/
struct mdtri2f {

    // Base triangle.
    tri2f base;
    alias base this;

    // indices of the tris used for looking up deltas.
    uint[3] indices;
}

/**
    A managed type handling the shape of a mesh deformer's vertices.
*/
struct MeshDeformerShape {
private:
@nogc:
    mdtri2f[] tris;
    vec2[] deltas;
    vec2[] tmp;

    vec2 getDeformDelta(vec2 p) {
        foreach(tri; tris) {
            uint i0 = tri.indices[0];
            uint i1 = tri.indices[1];
            uint i2 = tri.indices[2];

            // // Do some cheaper checks first.
            // float minX = min(min(tri.p0.x, tri.p1.x), tri.p2.x);
            // float maxX = max(max(tri.p0.x, tri.p1.x), tri.p2.x);
            // float minY = min(min(tri.p0.y, tri.p1.y), tri.p2.y);
            // float maxY = max(max(tri.p0.y, tri.p1.y), tri.p2.y);
            // if (!(minX < p.x && maxX > p.x) &&
            //     !(minY < p.y && maxY > p.y))
            //     continue;

            if (tri.contains(p)) {
                vec3 bc = tri.barycentric(p);
                vec2 d0 = deltas[i0]*bc.x;
                vec2 d1 = deltas[i1]*bc.y;
                vec2 d2 = deltas[i2]*bc.z;
                return -(d0+d1+d2);
            }
        }
        return vec2(0, 0);
    }

public:

    /**
        Whether the shape is ready for use.
    */
    @property bool isReady() => deltas.length > 0;

    /**
        Axis aligned bounding box encompassing the vertices.
    */
    rect aabb;

    /// Destructor
    ~this() {
        nu_freea(deltas);
        nu_freea(tmp);
    }

    /**
        Sets the mesh of the deformer shape.
    */
    void setMesh(Mesh mesh) {
        size_t numTris = mesh.indices.length/3;
        if (tris.length != numTris)
            tris = tris.nu_resize(numTris);

        if (deltas.length != numTris)
            deltas = deltas.nu_resize(numTris);

        foreach(t; 0..numTris) {
            tris[t].indices = [
                mesh.indices[(t*3)+0],
                mesh.indices[(t*3)+1],
                mesh.indices[(t*3)+2]
            ];
        }
    }

    /**
        Updates the mesh deformer shape with the given deformed
        vertices.
    */
    void update(vec2[] base, vec2[] deformed) {
        simd_meshcopy(deltas, base);
        simd_sub(deltas, deformed);
        simd_aabb(aabb, base);

        // Fill out tris
        foreach(i; 0..tris.length) {
            tris[i].p0 = base[tris[i].indices[0]];
            tris[i].p1 = base[tris[i].indices[1]];
            tris[i].p2 = base[tris[i].indices[2]];
        }
    }

    /**
        Deforms the given mesh using this shape.
    */
    void deformMesh(IDeformable mesh) {
        size_t w_length = mesh.deformPoints.length;

        // Prepare temporary buffer.
        if (w_length > tmp.length) 
            tmp = tmp.nu_resize(w_length);
        tmp[0..w_length] = vec2(0, 0);
        
        // Calculate the deformation needed by each vertex
        // in the mesh.
        foreach(i; 0..w_length) {

            vec2 delta = getDeformDelta(mesh.deformPoints[i]);
            if (delta != vec2.init)
                tmp[i] = delta;
        }
        mesh.deform(tmp[0..w_length], false);
    }
}