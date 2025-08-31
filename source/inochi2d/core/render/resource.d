/**
    Inochi2D GPU Resource Interface

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.render.resource;
import numem;

/**
    Current status of a resource
*/
enum ResourceStatus : int {

    /**
        Resource is ready for use.
    */
    ok = 0,
    
    /**
        A new resource should be created and an ID allocated to it
        by the rendering API.
    */
    wantsCreate = 1,
    
    /**
        A resource wants updates to its data or shape.
    */
    wantsUpdates = 2,
    
    /**
        A resource requests that it be deleted.
    */
    wantsDeletion = 3
}

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
        Current status of the resource.
    */
    ResourceStatus status;

    /**
        ID of a resource, differs based on the underlying
        rendering API.
    */
    ResourceID id;

    /**
        Finalizes a resource update.
    */
    abstract void finalize();

    /**
        Requests the deletion of this resource.
    */
    final
    void requestDelete() {
        this.status = ResourceStatus.wantsDeletion;
    }
}