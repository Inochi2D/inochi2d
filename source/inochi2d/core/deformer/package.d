module inochi2d.core.deformer;
import inochi2d.core.mesh;

/**
    A deformer that deforms verticies of DynMeshes
*/
abstract class Deformer {
protected:
    DynMesh mesh;

public:

    /**
        The blends of the deformer
    */
    @Named("Blends")
    Parameter blends;

    /**
        Construct a deformer
    */
    this(DynMesh mesh) {
        this.mesh = mesh;
    }

    /**
        Derforms a mesh
    */
    abstract void deform();
}