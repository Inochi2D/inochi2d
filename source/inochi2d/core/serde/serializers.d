/**
    Inochi2D Serializer Interface

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
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
