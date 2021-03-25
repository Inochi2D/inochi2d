module inochi2d.core.deformer.shapedeformer;
import inochi2d.core.deformer;

/**
    A deformer that deforms via shapes
*/
class ShapeDeformer : Deformer {

    /**
        Constructor
    */
    this(Deformer parent = null) { 
        super(DeformerType.Shape, parent); 
    }
    
}