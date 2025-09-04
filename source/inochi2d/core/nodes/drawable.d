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

public import inochi2d.core.mesh;

/**
    Nodes that are meant to render something in to the Inochi2D scene
    Other nodes don't have to render anything and serve mostly other 
    purposes.

    The main types of Drawables are Parts and Masks
*/

@TypeId("Drawable")
abstract class Drawable : Node, IDeformable {
private:
    vec2[] _deformed;

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
    }

public:

    abstract void renderMask(bool dodge = false);

    /**
        The points which may be deformed by the deformer.
    */
    override @property vec2[] deformPoints() => _deformed;

    /**
        Deforms the IDeformable.

        Params:
            deformed =  The deformation delta.
            absolute =  Whether the deformation is absolute,
                        replacing the original deformation.
    */
    override void deform(vec2[] deformed, bool absolute) {
        import nulib.math : min;
        
        size_t m = min(deformPoints.length, deformed.length);
        if (absolute)
            deformPoints[0..m] = deformed[0..m];
        else
            deformPoints[0..m] += deformed[0..m];
    }

    /**
        Resets the deformation for the IDeformable.
    */
    override void resetDeform() {
        if (this._deformed.length != this.mesh.vertices.length)
            this._deformed.length = this.mesh.vertices.length;
        this._deformed[0..$] = this.mesh.points[0..$];
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
        this.mesh = Mesh.fromMeshData(data);
    }

    /**
        The mesh of the model.
    */
    Mesh mesh;

    override
    void beginUpdate() {
        this.resetDeform();
        super.beginUpdate();
    }

    /**
        Updates the drawable
    */
    override
    void update() {
        super.update();
    }

    /**
        Draws the drawable
    */
    override
    void drawOne(float delta) {
        super.drawOne(delta);
    }

    /**
        Draws the drawable without any processing
    */
    void drawOneDirect(bool forMasking) { }

    override
    string typeId() { return "Drawable"; }
}