module inochi2d.core.serde.serializers;
import inochi2d.core.math;
import inochi2d.core;
import inp.format;
import numath;

/**
    Whether type T can be serialized.
*/
enum isSerializable(T) =
    is(T : ISerializable) ||
    is(typeof((ref DataNode obj) { T a; a.onSerialize(obj); }));

/**
    Interface for classes that can be serialized to JSON with custom code
*/
interface ISerializable {

    /**
        Custom serializer function
    */
    void onSerialize(ref DataNode object);
}
