/**
    Common Parameter types and helpers.

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.buffer;
import numem;

/**
    A simple wrapper for a storage buffer that can be grown by a given
    size, using pagnation.
*/
struct StorageBuffer {
public:
@nogc:
    float[] data;

    /**
        Grows the parameter buffer to the given length and initializes
        it with zeroes.

        Params:
            by = The amount of bytes to grow the buffer by.

        Returns:
            The previous length of the buffer.
    */
    size_t grow(ptrdiff_t by) {
        ptrdiff_t newLength = (cast(ptrdiff_t)this.data.length+by);
        if (newLength >= 0) {
            size_t oldLength = data.length;
            
            this.data = data.nu_resize(newLength);
            if (oldLength < newLength) {
                this.data[oldLength..$] = 0f;
            }
            return oldLength;
        }
        
        this.free();
        return 0;
    }

    /**
        Removes the given range from the buffer, shrinking it.

        Params:
            start =     The index to start from.
            length =    The amount of indices to remove.
    */
    void removeRange(size_t start, size_t length) {
        size_t end = start+length;
        
        // Case: Out of bounds.
        if (end > data.length || length == 0)
            return;

        // Case: Remove everything.
        if (start == 0 && length == data.length) {
            this.free();
            return;
        }


        // Case: Remove sub-area.

        // If need be, shift everything down.
        if (start+length < data.length) {

            size_t toShift = data.length-end;
            data[start..start+toShift] = data[end..end+toShift];
        }

        // Then re-slice our allocation.
        this.data = data[0..(data.length-length)];
    }

    /**
        Frees the buffer.
    */
    void free() {
        nu_cleara(data);
    }
}

/**
    Moves a single element within a slice to a given location.

    Params:
        slice = The slice to shift data within.
        from =  The index of the element to shift.
        to =    The index to shift the element to.
*/
void moveElement(T)(T[] slice, size_t from, size_t to) @nogc nothrow {
    
    // Nothing to do.
    if (from == to)
        return;

    T tmp = slice[from];
    if (to < from) {
    
        // Move element left
        nu_memmove(&slice[to+1], &slice[to], (from-to)*T.sizeof);
        slice[to] = tmp;

    } else {
    
        // Move element right
        nu_memmove(&slice[from], &slice[from+1], (to-from)*T.sizeof);
        slice[to] = tmp;

    }
}

@("move test")
unittest {
    float[32] a = 0f;
    a[1] = 24;

    a.moveElement(1, 0);
    assert(a[0] == 24 && a[1] == 0);

    a.moveElement(0, 10);
    assert(a[10] == 24 && a[0] == 0);
}