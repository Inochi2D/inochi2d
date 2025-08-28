/**
    Inochi2D GPU Buffers

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.render.buffer;
import numem;

/**
    A buffer of data
*/
class Buffer : NuRefCounted {
private:
@nogc:
    bool dirty;
    uint allocated;
    void[] staging;

public:

    /**
        Gets the length of the buffer in bytes.
    */
    @property uint length() => allocated;

    /**
        Creates a new buffer.
    */
    this(uint sizeInBytes) {
        this.allocated = sizeInBytes;
        this.staging = nu_malloca!ubyte(sizeInBytes);
    }

    /**
        Resizes the buffer.
    */
    void resize(uint newSize) {
        this.staging = staging.nu_resize(newSize);
        this.allocated = newSize;
    }

    /**
        Maps the buffer and marks it dirty.
    */
    void[] map() {
        this.dirty = true;
        return staging;
    }

    /**
        Finalizes the buffer, marking it no longer dirty.

        In debug mode, the buffer will additionally be
        zero-filled.
    */
    void finalize() {
        this.dirty = false;
        debug {
            (cast(ubyte[])staging)[0..$] = 0;
        }
    }
}