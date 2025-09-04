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
    VtxData[] _deformed;

protected:
    void updateDeform() {
        postProcess();
    }

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void serializeSelfImpl(ref JSONValue object, bool recursive=true) {
        super.serializeSelfImpl(object, recursive);

        MeshData data = mesh.toMeshData();
        object["mesh"] = data.serialize();
    }

    override
    void onDeserialize(ref JSONValue object) {
        super.onDeserialize(object);
        this.mesh = Mesh.fromMeshData(object.tryGet!MeshData("mesh"));
    }

    void onDeformPushed(ref Deformation deform) { }

    override
    void preProcess() {
        // if (preProcessed)
        //     return;
        // preProcessed = true;
        // if (preProcessFilter !is null) {
        //     overrideTransformMatrix = null;
        //     mat4 matrix = this.transform.matrix;
        //     auto filterResult = preProcessFilter(vertices, deformation, &matrix);
        //     if (filterResult[0] !is null) {
        //         deformation = filterResult[0];
        //     } 
        //     if (filterResult[1] !is null) {
        //         overrideTransformMatrix = new MatrixHolder(*filterResult[1]);
        //     }
        // }
    }

    override
    void postProcess() {
        // if (postProcessed)
        //     return;
        // postProcessed = true;
        // if (postProcessFilter !is null) {
        //     overrideTransformMatrix = null;
        //     mat4 matrix = this.transform.matrix;
        //     auto filterResult = postProcessFilter(vertices, deformation, &matrix);
        //     if (filterResult[0] !is null) {
        //         deformation = filterResult[0];
        //     } 
        //     if (filterResult[1] !is null) {
        //         overrideTransformMatrix = new MatrixHolder(*filterResult[1]);
        //     }
        // }
    }

package(inochi2d):
    final void notifyDeformPushed(ref Deformation deform) {
        onDeformPushed(deform);
    }

public:

    abstract void renderMask(bool dodge = false);

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
        this(data, inCreateUUID(), parent);
    }

    /**
        Constructs a new drawable surface
    */
    this(MeshData data, uint uuid, Node parent = null) {
        super(uuid, parent);
        this.mesh = Mesh.fromMeshData(data);
    }

    /**
        The mesh of the model.
    */
    Mesh mesh;

    override
    void beginUpdate() {
        if (this._deformed.length != this.mesh.vertices.length)
            this._deformed.length = this.mesh.vertices.length;
        this._deformed[0..$] = this.mesh.vertices[0..$];

        super.beginUpdate();
    }

    /**
        Updates the drawable
    */
    override
    void update() {
        this.preProcess();
        super.update();
        this.updateDeform();
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