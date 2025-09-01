/**
    Inochi2D GPU Buffers

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.render.buffer;
import inochi2d.core.render.resource;
import numem;

/**
    Buffer usage flags.
*/
enum BufferUsage : uint {

    /**
        Buffer is used for vertex data.
    */
    vertex = 0,
    
    /**
        Buffer is used for index data.
    */
    index = 1,
    
    /**
        Buffer is used for uniform data.
    */
    uniform = 2
}

/**
    A data buffer that can be used in rendering.
*/
class Buffer : Resource {
private:
@nogc:
    BufferUsage usage_;
    void[] staging;

public:

    /**
        How the buffer will be used.
    */
    @property BufferUsage usage() => usage_;

    /**
        Staging area on the CPU-side for data updates.
    */
    final @property void[] data() => staging;

    /**
        Gets the length of the buffer in bytes.
    */
    override @property uint length() => cast(uint)staging.length;

    /**
        Creates a new buffer.
    */
    this(uint sizeInBytes, BufferUsage usage) {
        this.status = ResourceStatus.wantsCreate;
        this.staging = nu_malloca!ubyte(sizeInBytes);
        this.usage_ = usage;
    }

    /**
        Resizes the buffer.
    */
    void resize(uint newSize) {
        this.status = ResourceStatus.wantsUpdates;
        this.staging = staging.nu_resize(newSize);
    }

    /**
        Finalizes the buffer, marking it no longer dirty.
    */
    override
    void finalize() {
        this.status = 
            status == ResourceStatus.wantsDeletion ? 
                status : 
                ResourceStatus.ok;
    }
}