module inochi2d.core.io.obj;
import inochi2d.core.io.serializer;

public import inochi2d.core.io.inp.node;
public import inochi2d.core.io.inp.ctx;

/**
    An Inochi2D Object which can be serialized and deserialized.
*/
abstract
class InObject {
@nogc:
protected:
    this() { }

public:
    
    /**
        Serialize the object
    */
    abstract void serialize(ref InpNode node, ref InpContext context);

    /**
        Deserialize the object
    */
    abstract void deserialize(ref InpNode node);

    /**
        Creates a copy of the object
    */
    abstract InObject copy();
}