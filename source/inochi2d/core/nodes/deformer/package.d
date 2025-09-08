/*
    Inochi2D Deformers

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.deformer;
import inochi2d.core.nodes;
import inochi2d.core.math;
import inochi2d.core;
import nulib;
import numem;

public import inochi2d.core.nodes.deformer.meshdeformer;
public import inochi2d.core.nodes.deformer.latticedeformer;

/**
    A node which deforms the vertex data of nodes beneath
    it.

    Deformations happen in world space
*/
@TypeId("Deformer", 0x0002)
@TypeIdAbstract
abstract
class Deformer : Node, IDeformable {
private:
    bool legacyMode_;

    void scanPartsRecurse(Node node) {

        // Don't need to scan null nodes
        if (node is null) return;

        // NOTE:    Backwards compatibility mode does not allow
        //          MeshGroup instances to be nested.
        if (legacyMode_ && cast(Deformer)node)
            return;

        // Do the main check
        if (IDeformable deformable = cast(IDeformable)node)
            toDeform ~= deformable;
        
        foreach(child; node.children) {
            scanPartsRecurse(child);
        }
    }

protected:

    /**
        A list of the nodes to deform.
    */
    IDeformable[] toDeform;
    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void onSerialize(ref JSONValue object, bool recursive=true) {
        super.onSerialize(object, recursive);
        object["legacyMode"] = legacyMode_;
    }

    override
    void onDeserialize(ref JSONValue object) {
        super.onDeserialize(object);
        this.legacyMode_ = object.tryGet!bool("legacyMode", true);
    }

    /**
        Finalizes the deformer.
    */
    override
    void finalize() {
        super.finalize();
        this.rescan();
    }

public:

    /**
        Whether deformers should act like MeshGroup when selecting
        nodes to deform.
    */
    final @property bool legacyMode() => legacyMode_;
    final @property void legacyMode(bool value) {
        this.legacyMode_ = value;
    }

    ~this() { }

    /**
        Constructs a new MeshGroup node
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        The control points of the deformer.
    */
    abstract @property vec2[] controlPoints();
    abstract @property void controlPoints(vec2[] value);

    /**
        The base position of the deformable's points.
    */
    abstract @property const(vec2)[] basePoints();

    /**
        Local matrix of the deformable object.
    */
    override @property Transform baseTransform() => transform!true;

    /**
        World matrix of the deformable object.
    */
    override @property Transform worldTransform() => transform!false;

    /**
        The points which may be deformed by the deformer.
    */
    override @property vec2[] deformPoints() => controlPoints();

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
        Deforms a single vertex in the IDeformable

        Params:
            offset =    The offset into the point list to deform.
            deform =    The deformation delta.
            absolute =  Whether the deformation is absolute,
                        replacing the original deformation.
    */
    override void deform(size_t offset, vec2 deform, bool absolute = false) {
        if (offset >= deformPoints.length)
            return;
        
        if (absolute)
            deformPoints[offset] = deform;
        else
            deformPoints[offset] += deform;
    }

    /**
        Applies an offset to the Node's transform.

        Params:
            other = The transform to offset the current global transform by.
    */
    override
    void offsetTransform(Transform other) {
        super.offsetTransform(other);
    }

    /**
        Resets the deformation for the IDeformable.
    */
    abstract void resetDeform();

    /**
        Rescans the children of the deformer.
    */
    void rescan() {
        toDeform.length = 0;
        foreach(child; children) {
            this.scanPartsRecurse(child);
        }
    }
}
mixin Register!(Deformer, in_node_registry);
