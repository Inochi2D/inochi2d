/**
    Inochi2D GPU Resource Interface

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
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