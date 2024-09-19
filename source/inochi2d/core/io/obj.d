module inochi2d.core.io.obj;
import inochi2d.core.io.serializer;

public import inochi2d.core.io.tree.value;
public import inochi2d.core.io.tree.ctx;

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
    abstract void serialize(ref InTreeValue node, ref InDataContext context);

    /**
        Deserialize the object
    */
    abstract void deserialize(ref InTreeValue node, ref InDataContext context);

    /**
        Finalize the object
    */
    abstract void finalize(ref InTreeValue node, ref InDataContext context);

    /**
        Creates a copy of the object
    */
    abstract InObject copy();
}