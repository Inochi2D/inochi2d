/**
    DataNode Array Abstraction

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inp.format.array;
import nulib.collections.internal.marray;
import numem.core.traits;
import numem.core.memory;
import numem.rc;
import numem;

/**
    A refcounted array
*/
struct RcArray(T) {
private:
@nogc:
    alias VStoreT = ManagedArray!T;
    Rc!VStoreT values;

public:
    alias data this;

    /**
        Length of the array.
    */
    @property size_t length() pure => values ? values.length : 0;

    /**
        The data stored in the refcounted array.
    */
    @property T[] data() => values ? values.value : null;

    /**
        Makes a new array.
    */
    static typeof(this) make() {
        typeof(this) result;
        result.values = Rc!(VStoreT)(VStoreT());
        return result;
    }

    /// Destructor
    ~this() nothrow @trusted {
        if (values) {
            values.release();
        }
    }

    /**
        Creates a new RC array with values copied from the given slice.

        Params:
            values = Slice of values to put into the array
    */
    this(T[] values) {
        this.values = Rc!(VStoreT)(VStoreT());
        this.values.resize(values.length);
        nu_memcpy(&this.values, &values, values.length*T.sizeof);
    }

    /**
        Copy-constructor
    */
    this()(auto ref return scope inout(typeof(this)) rhs) pure nothrow @trusted {
        nu_memmove(&values, &rhs.values, typeof(values).sizeof);
        if (values)
            values.retain();
    }

    /**
        Assigns an element of the array.

        Params:
            i =     The index to set.
            value = The value to set.
    */
    void opIndexAssign()(auto ref TValue value, size_t i) {
        assert(values);
        assert(i < length);

        this.values[i] = value;
    }

    /**
        Assignment operator
    */
    void opAssign()(auto ref return scope inout(typeof(this)) rhs) {
        if (values)
            values.release();
        
        nu_memmove(&values, &rhs.values, typeof(values).sizeof);
        if (values)
            values.retain();
    }

    /**
        Adds the given entry into the array.

        Params:
            rhs = Value to append
    */
    void opOpAssign(string op)(T rhs)
    if (op == "~") {
        this.values.resize(values.length+1);
        this.values[$-1] = rhs;
    }

    /**
        Adds the given entry into the array.

        Params:
            rhs = Value to append
    */
    void opOpAssign(string op)(T[] rhs)
    if (op == "~") {
        assert(rhs.ptr-values.ptr >= 0);

        ptrdiff_t copyStart = rhs.ptr-values.ptr;
        ptrdiff_t copyLength = rhs.length;
        ptrdiff_t copyEnd = copyOffset+copyLength;
        bool overlap = nu_is_overlapping(values.ptr, values.length, rhs.ptr, rhs.length);
        this.values.resize(values.length+rhs.length);

        // On overlap we need to readjust our input slice.
        if (overlap) 
            rhs = values[copyStart..copyEnd];

        this.values[copyEnd..copyEnd+copyLength] = rhs[copyStart..copyEnd];
    }

    /**
        Removes the given key from the object.

        Params:
            i = The index to remove.
    */
    void remove()(size_t i) {
        assert(i < values.length);
        values.deleteRange(values[i..i+1]);
    }

    /**
        Resizes the reference counted array.

        Params:
            length = The new length.
    */
    void resize(size_t length) {
        this.values.resize(length);
    }

    /**
        Indexes the array.

        Params:
            i = The index.

        Returns:
            The item at the index.
    */
    auto ref T opIndex()(size_t i) {
        assert(i < values.value.length);
        return values[i];
    }

    /**
        Dict-iterator
    */
    int opApply(scope int delegate(ref size_t index, ref T value) dg) {
        if (!values)
            return 0;
        
        auto dgf = cast(int delegate(ref size_t index, ref T value) @nogc scope)dg;
        foreach (i; 0..values.length) {
            int result = dgf(i, values[i]);
            if (result)
                return result;
        }
        return 0;
    }

    /**
        Dict-iterator
    */
    int opApply(scope int delegate(ref T value) dg) {
        if (!values)
            return 0;
        
        auto dgf = cast(int delegate(ref T value) @nogc scope)dg;
        foreach (i; 0..values.length) {
            int result = dgf(values[i]);
            if (result)
                return result;
        }
        return 0;
    }
}

/// UTF8 refcounted string
alias RcString = RcArray!char;