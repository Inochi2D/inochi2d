/**
    Inochi2D Deformer Nodes

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.nodes.deformer;
import inochi2d.nodes;
import inochi2d.common;
import inochi2d.core;
import nulib;
import numem;

public import inochi2d.nodes.deformer.meshdeformer;
public import inochi2d.nodes.deformer.latticedeformer;

/**
    A node which deforms the vertex data of nodes beneath
    it.

    Deformations happen in world space
*/
@TypeId("Deformer", MAKE_I2D_TAG!(0, 2))
@TypeIdAbstract
abstract
class Deformer : Node, IDeformable {
private:
@nogc:
    weak_vector!IDeformable toDeform_;

    void scanPartsRecurse(Node node) {

        // Don't need to scan null nodes
        if (node is null)
            return;

        // Do the main check
        if (IDeformable deformable = cast(IDeformable)node)
            toDeform_ ~= deformable;

        // Deformers already deform their children, and we deform
        // them first, so don't exaggerate it through their children
        if (!cast(Deformer)node) {
            foreach (child; node.children) {
                this.scanPartsRecurse(child);
            }
        }
    }

protected:

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
    */
    override
    void onSerialize(ref DataNode object) {
        super.onSerialize(object);
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object =    The DataNode to deserialize from.
            state =     The state of the deserializer.
    */
    override
    void onDeserialize(ref DataNode object, ref ModelState state) {
        super.onDeserialize(object, state);
    }

    /**
        Called when the node is to finalize its deserialization from disk.
    */
    override
    void onFinalize() @nogc {
        super.onFinalize();
        this.rescan();
    }

public:

     ~this() {
    }

    /**
        Constructs a new MeshGroup node
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        A list of the nodes to deform.
    */
    @property IDeformable[] toDeform() => toDeform_[0 .. $];

    /**
        The control points of the deformer.
    */
    abstract @property vec2[] controlPoints() @nogc;
    abstract @property void controlPoints(vec2[] value) @nogc;

    /**
        The base position of the deformable's points.
    */
    abstract @property const(vec2)[] basePoints() @nogc;

    /**
        The base matrix of the object before any parameters have been applied.
    */
    override @property Basis deformBaseMatrix() @nogc => baseMatrix;

    /**
        World matrix of the deformable object.
    */
    override @property Basis deformMatrix() @nogc => matrix;

    /**
        The points which may be deformed by the deformer.
    */
    override @property vec2[] deformPoints() @nogc => controlPoints();

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
            deformPoints[0 .. m] = deformed[0 .. m];
        else
            deformPoints[0 .. m] += deformed[0 .. m];
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
        Resets the deformation for the IDeformable.
    */
    abstract void resetDeform();

    /**
        Rescans the children of the deformer.
    */
    void rescan() {
        toDeform_.clear();
        foreach (child; children) {
            this.scanPartsRecurse(child);
        }
    }
}

mixin Register!(Deformer, in_node_registry);
