/*
    Inochi2D Common Data

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.common;
import inochi2d.core.nodes.drawable;
import inochi2d.core.render.state;
import inochi2d.core.format;
import inochi2d.core;

/**
    A binding between a mask and a mode
*/
struct MaskBinding {
public:
    GUID maskSrcGUID;
    MaskingMode mode;
    Drawable maskSrc;

    /**
        Serialization function
    */
    void onSerialize(ref JSONValue object, bool recursive = true) {
        auto srcGuid = maskSrcGUID.toString();
        object["source"] = srcGuid.dup;
        object["mode"] = mode;
    }

    /**
        Deserialization function
    */
    void onDeserialize(ref JSONValue object) {
        maskSrcGUID = object.tryGetGUID("source", "source");
        mode = object.tryGet!string("mode", null).toMaskingMode;
    }
}