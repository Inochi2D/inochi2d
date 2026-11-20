/**
    Inochi2D Mesh Resource

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.resource.mesh;
import inochi2d.resource;
import inochi2d.common;
import inochi2d.core.serde;
import numath;
import numem;

public import numath.tri : tri2f;

/**
    A collection of vertices that makes up a visual object in the
    Inochi2D scene tree.
*/
class Mesh : Resource {
private:
@nogc:

    //-----------------------------------------------------------------------//
    //                                Mesh Data
    //-----------------------------------------------------------------------//
    Material material_;
    uint[] indices_;
    vec2[] vertices_;
    vec2[] uvs_;

    //-----------------------------------------------------------------------//
    //                                 Metadata
    //-----------------------------------------------------------------------//
    rect aabb_;

    /**
        Recalculates the mesh bounding box.
    */
    void recalculateAABB() {
        vec2 minp = vec2(float.max, float.max);
        vec2 maxp = vec2(-float.max, -float.max);

        foreach (i; 0 .. vertices_.length) {
            minp = vec2(min(minp.x, vertices_[i].x), min(minp.y, vertices_[i].y));
            maxp = vec2(max(maxp.x, vertices_[i].x), max(maxp.y, vertices_[i].y));
        }
        this.aabb_ = rect(minp.x, minp.y, maxp.x - minp.x, maxp.y - minp.y);
    }

public:

    /**
        Length of the resource's data allocation in bytes.
    */
    override @property size_t length() nothrow pure => 
        (indices_.length * uint.sizeof) +
        (vertices_.length * vec2.sizeof) +
        (uvs_.length * vec2.sizeof);

    /**
        The material applied to the mesh.
    */
    @property Material material() nothrow => material_;
    @property void material(Material value) nothrow {
        auto oldValue = material_;
        this.material_ = value.retained;

        if (oldValue)
            oldValue.release();
    }

    /**
        Indices of the mesh.
    */
    @property uint[] indices() nothrow pure => indices_;

    /**
        Vertex coordinates of the mesh.
    */
    @property vec2[] vertices() nothrow pure => vertices_;

    /**
        UV coordinates of the mesh.
    */
    @property vec2[] uvs() nothrow pure => uvs_;

    /**
        Axis aligned bounding box encompassing the entire mesh.
    */
    @property rect bounds() => aabb_;

    /// Destructor
    ~this() {
        nu_freea(indices_);
        nu_freea(vertices_);
        nu_freea(uvs_);
        if (material_) {
            this.material_.release();
            this.material_ = null; 
        }
    }

    /**
        Constructs an empty mesh.
    */
    this() { }




    //-----------------------------------------------------------------------//
    //                                 Mutation
    //-----------------------------------------------------------------------//

    /**
        Makes a new mesh identical to this one.

        Returns:
            The deep clone of this mesh.
    */
    Mesh clone() {
        Mesh mesh = nogc_new!Mesh();
        mesh.material_ = this.material_ ? this.material_.retained : null;
        mesh.indices_ = this.indices_.nu_dup();
        mesh.vertices_ = this.vertices_.nu_dup();
        mesh.uvs_ = this.uvs_.nu_dup();
        mesh.recalculateAABB();
        return mesh;
    }

    /**
        Destructively offsets the entire mesh by the given offset.

        Params:
            offset = The offset to apply to the mesh.

        Returns:
            This mesh instance.
    */
    typeof(this) offset(vec2 offset) {
        if (offset.isFinite) {
            foreach (i; 0 .. this.vertices_.length) {
                this.vertices_[i] += offset;
            }
            this.recalculateAABB();
        }
        return this;
    }

    /**
        Destructively scales the entire mesh by the given scale.

        Params:
            scale = The amount to scale the mesh by.

        Returns:
            This mesh instance.
    */
    typeof(this) scale(vec2 scale) {
        if (scale.isFinite) {
            foreach (i; 0 .. this.vertices_.length) {
                this.vertices_[i] *= scale;
            }
            this.recalculateAABB();
        }
        return this;
    }

    /**
        Destructively applies the given matrix to this mesh.

        Params:
            matrix = The matrix to apply.

        Returns:
            This mesh instance.
    */
    typeof(this) applyMatrix(mat3 matrix) {
        foreach (i; 0 .. this.vertices_.length) {
            this.vertices_[i] *= matrix;
        }
        this.recalculateAABB();
        return this;
    }




    //-----------------------------------------------------------------------//
    //                               Inspection
    //-----------------------------------------------------------------------//

    /**
        Creates a triangle list from this mesh.

        Returns:
            A freshly allocated triangle list slice, must be freed with
            $(D nu_freea).
    */
    tri2f[] toTriList() {
        tri2f[] list = nu_malloca!tri2f(indices_.length / 3);
        foreach(i; 0.. list.length) {
            list[i] = tri2f(
                vertices_[indices_[(i * 3) + 0]],
                vertices_[indices_[(i * 3) + 1]],
                vertices_[indices_[(i * 3) + 2]],
            );
        }
        return list;
    }

    /**
        Gets the triangle at the given offset.

        Params:
            offset = The offset of the triangle in the mesh.

        Returns:
            The triangle at the given offset if found,
            $(D tri2f.init) otherwise.
    */
    tri2f triangleAt(size_t offset) {
        if (offset >= indices_.length / 3)
            return tr2if.init;

        return tri2f(
            vto_[idx_[(offset * 3) + 0]],
            vto_[idx_[(offset * 3) + 1]],
            vto_[idx_[(offset * 3) + 2]]
        );
    }




    //-----------------------------------------------------------------------//
    //                                  Serde
    //-----------------------------------------------------------------------//

    /**
        Creates a mesh from a Inochi2D 0.8 mesh definition.

        Params:
            object =    The datanode of the Inochi2D 0.8 "mesh" key
            state =     The state of the deserializer.

        Returns:
            A new $(D Mesh) with the data from the Inochi2D 0.8 mesh definition,
            $(D null) on failure.
    */
    static Mesh createFromLegacy(ref DataNode object, ref ModelState state) {
        if (object.isNull)
            return;

        Mesh mesh = nogc_new!Mesh();

        // Load vertices as tightly packed floats.
        float[] vtxbuf;
        object.tryGetRef(state, vtxbuf, "verts");
        mesh.vertices_ = cast(vec2[])vtxbuf[0 .. nu_aligndown(vtxbuf.length, 2)];

        // Load UVs as tightly packed floats.
        float[] uvbuf;
        object.tryGetRef(state, uvbuf, "uvs");
        mesh.uvs_ = cast(vec2[])uvbuf[0 .. nu_aligndown(uvbuf.length, 2)];

        // Load indices.
        object.tryGetRef(state, mesh.indices_, "indices");

        // Apply origin transform destructively.
        vec2 origin = object.tryGet!vec2(state, "origin");
        mesh.offsetBy(-origin);

        mesh.recalculateAABB();
        return mesh;
    }
}