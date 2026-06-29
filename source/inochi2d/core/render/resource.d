/**
    Inochi2D GPU Resource Interface

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.render.resource;
import numem;

/**
    An ID managed by the backend rendering API.
*/
alias ResourceID = void*;

/**
    A resource that can be transferred between CPU and GPU.
*/
abstract
class Resource : NuRefCounted {
public:
@nogc:

    /**
        Length of the resource's data allocation in bytes.
    */
    abstract @property uint length();

    /**
        ID of a resource, differs based on the underlying
        rendering API.
    */
    ResourceID id;
}
