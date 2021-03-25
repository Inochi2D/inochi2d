module inochi2d.core.deformer.hingedeformer;
import inochi2d.core.deformer;
import inochi2d.math;
import inochi2d.core.mesh;
import inochi2d.math;

/**
    A deformer that allows rotating things around a joint
*/
class HingeDeformer : Deformer {
    
    /**
        Minimum rotation
    */
    float minRotation;

    /**
        Maximum rotation
    */
    float maxRotation;

    /**
        Sets the rotation of the hinge
    */
    void rotateTo(float value) {
        rotation = mat3.zrotation(clamp(value, minRotation, maxRotation));
    }

    /**
        Constructor
    */
    this(Deformer parent = null) { 
        super(DeformerType.Hinge, parent); 
    }
}