/*
    Inochi2D Common Data

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.common;
import inochi2d.core.render.state;
import inochi2d.core.format;

/**
    A binding between a mask and a mode
*/
struct MaskBinding {
public:
    import inochi2d.core.nodes.drawable : Drawable;
    uint maskSrcUUID;

    MaskingMode mode;
    
    Drawable maskSrc;


    /**
        Serialization function
    */
    void onSerialize(ref JSONValue object) {
        object["uuid"] = maskSrcUUID;
        object["mode"] = mode;
    }

    /**
        Deserialization function
    */
    void onDeserialize(ref JSONValue object) {
        object.tryGetRef(maskSrcUUID, "uuid");
        mode = object.tryGet!string("mode").toMaskingMode;
    }
}