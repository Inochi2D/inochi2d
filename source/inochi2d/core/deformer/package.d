module inochi2d.core.deformer;
import inochi2d.core.mesh;
import inochi2d.math;

public import inochi2d.core.deformer.hingedeformer;
public import inochi2d.core.deformer.shapedeformer;

/**
    The types possible for a deformer
*/
enum DeformerType : ubyte {
    /**
        A deformer that rotates other deformers or objects around a point
    */
    Hinge = 0x00,

    /**
        A deformer that deforms a shape
    */
    Shape = 0x01
}

/**
    A deformer that deforms verticies of DynMeshes
*/
abstract class Deformer {
private:

    /**
        The type of a deformer
    */
    DeformerType type;

public:

    /**
        The origin transform of the deformer
    */
    mat3 translation;

    /**
        Rotation of the deformer
    */
    mat3 rotation;

    /**
        Scale of the deformer
    */
    mat3 scale;

    /**
        parent deformer
    */
    Deformer parent;

    /**
        Constructs a new deformer of the specified type
    */
    this(DeformerType type, Deformer parent = null) {
        this.type = type;
        this.parent = parent;
    }

    // TODO: Implement a constructor for deformers based on
    // Exported model data

    /**
        Gets the origin point of the transform
    */
    mat3 transform() {
        if (parent is null) return scale * rotation * translation;
        return parent.transform * scale * rotation * translation;
    }

    /**
        Gets whether the deformer is a shape deformer
    */
    bool isShapeDeformer() {
        return type == DeformerType.Shape;
    }

    /**
        Gets whether the deformer is a hinge deformer
    */
    bool isHingeDeformer() {
        return type == DeformerType.Hinge;
    }

    /**
        Gets the shape deformer of this deformer
    */
    ShapeDeformer getSelfShape() {
        assert(isShapeDeformer(), "Not a shape deformer");
        return cast(ShapeDeformer)this;
    }

    /**
        Gets the hinge deformer of this deformer
    */
    HingeDeformer getSelfHinge() {
        assert(isHingeDeformer(), "Not a hinge deformer");
        return cast(HingeDeformer)this;
    }
}