/*
    Inochi2D Drawable base class

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.drawable;
import inochi2d.core.format;
import inochi2d.core.math;
import std.exception;
import inochi2d.core;
import std.string;

import inteli;
import numem;

public import inochi2d.core.mesh;
public import inochi2d.core.nodes.drawable.part;
public import inochi2d.core.nodes.drawable.apart;

/**
    Nodes that are meant to render something in to the Inochi2D scene
    Other nodes don't have to render anything and serve mostly other 
    purposes.

    The main types of Drawables are Parts and Masks
*/
@TypeId("Drawable", 0x0001)
@TypeIdAbstract
abstract class Drawable : Node, IDeformable {
private:
    Mesh mesh_;
    DeformedMesh deformed_;

protected:

    /**
        The current active draw list slot for this
        drawable.
    */
    DrawListAlloc* drawListSlot;

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void onSerialize(ref JSONValue object, bool recursive=true) {
        super.onSerialize(object, recursive);

        MeshData data = mesh_.toMeshData();
        object["mesh"] = data.serialize();
    }

    override
    void onDeserialize(ref JSONValue object) {
        super.onDeserialize(object);
        this.mesh_ = Mesh.fromMeshData(object.tryGet!MeshData("mesh"));
        this.deformed_ = nogc_new!DeformedMesh(mesh_);
    }

public:

    /**
        The mesh of the drawable.
    */
    final @property Mesh mesh() @nogc => mesh_;
    final @property void mesh(Mesh value) @nogc {
        if (value is mesh_)
            return;
        
        if (mesh_)
            mesh_.release();

        this.mesh_ = value.retained();
        this.deformed_.parent = value;
    }

    /**
        Local matrix of the deformable object.
    */
    override @property mat4 localMatrix() => transform.matrix;

    /**
        World matrix of the deformable object.
    */
    override @property mat4 worldMatrix() => globalTransform.matrix;

    /**
        The base position of the deformable's points.
    */
    @property const(vec2)[] basePoints() => mesh_.points;

    /**
        The points which may be deformed by the deformer.
    */
    override @property vec2[] deformPoints() => deformed_.points;

    /**
        Deforms the IDeformable.

        Params:
            deformed =  The deformation delta.
            absolute =  Whether the deformation is absolute,
                        replacing the original deformation.
    */
    override void deform(vec2[] deformed, bool absolute = false) {
        deformed_.deform(deformed);
    }

    /**
        Resets the deformation for the IDeformable.
    */
    override void resetDeform() {
        deformed_.reset();
    }

    ~this() {
        mesh_.release();
        nogc_delete(deformed_);
    }

    /**
        Constructs a new drawable surface
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        Constructs a new drawable surface
    */
    this(MeshData data, Node parent = null) {
        this(data, inNewGUID(), parent);
    }

    /**
        Constructs a new drawable surface
    */
    this(MeshData data, GUID guid, Node parent = null) {
        super(guid, parent);
        
        this.mesh_ = Mesh.fromMeshData(data);
        this.deformed_ = nogc_new!DeformedMesh(mesh_);
    }

    /**
        The mesh of the model.
    */

    override
    void preUpdate(DrawList drawList) {
        super.preUpdate(drawList);
        this.resetDeform();
    }

    /**
        Updates the drawable
    */
    override
    void update(float delta, DrawList drawList) {
        super.update(delta, drawList);
        deformed_.pushMatrix(transform.matrix);
    }

    /**
        Post-update
    */
    override
    void postUpdate(DrawList drawList) {
        super.postUpdate(drawList);
        this.drawListSlot = drawList.allocate(deformed_.vertices, deformed_.indices);
    }

    /**
        Draws the drawable to the screen.
    */
    override
    void draw(float delta, DrawList drawList) {
        drawList.setMesh(drawListSlot);
    }
    
    /**
        Draws the drawable to the screen in masking mode.
    */
    void drawAsMask(float delta, DrawList drawList, MaskingMode mode) {
        drawList.setMesh(drawListSlot);
    }
}