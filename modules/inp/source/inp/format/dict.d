/**
    DataNode Key-Value Pair Abstraction

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.dict;
import nulib.collections.internal.marray;
import numem.core.traits;
import numem.rc;
import numem;

/**
    An ordered refcounted dictionary.
*/
struct RcOrderedDictionary(TKey, TValue) {
private:
@nogc:
    alias KVT = KV!(TKey, TValue);
    alias KVStoreT = ManagedArray!(KV!(TKey, TValue));
    Rc!KVStoreT values;

    /// Helper that finds an entry by its key.
    pragma(inline, true)
    ptrdiff_t findEntry()(auto ref inout(TKey) key) inout nothrow {
        if (!values) return -1;

        foreach(i, ref entry; values) {
            if (entry.key == key)
                return i;
        }
        return -1;
    }

public:

    /**
        Makes a new ordered dictionary.
    */
    static typeof(this) make() {
        typeof(this) result;
        result.values = Rc!(KVStoreT)(KVStoreT());
        return result;
    }

    /// Destructor
    ~this() nothrow @trusted {
        if (values) {
            values.release();
        }
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
        Length of the node.
    */
    @property size_t length() pure => values ? values.length : 0;

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
        Removes the given key from the object.

        Params:
            key = The key to remove.
    */
    void remove()(auto ref TKey key) {
        ptrdiff_t idx = findEntry(key);
        if (idx >= 0) {
            values.deleteRange(values[idx..idx+1]);
        }
    }

    /**
        Assigns an element of the dictionary.

        Params:
            key =   The key to query.
            value = The value to set.
    */
    void opIndexAssign()(auto ref TValue value, auto ref TKey key) {
        if (!values)
            this.values = Rc!(KVStoreT)(KVStoreT());

        ptrdiff_t idx = findEntry(key);
        if (idx >= 0) {
            values[idx] = KV!(TKey, TValue)(key, value);
            return;
        }

        // Append our new entry.
        values.value.resize(values.length+1);
        values[$-1] = KV!(TKey, TValue)(key, value);
    }

    /**
        Gets whether the given key is present in the object.

        Params:
            key = The key to query.

        Returns:
            $(D true) if the object contains a value with the given key,
            $(D false) otherwise.
    */
    inout(TValue)* opBinaryRight(string op)(auto ref TKey key) inout nothrow
    if (op == "in") {
        inout idx = findEntry(key);
        return idx != -1 ? &(values[idx].value) : null;
    }

    /**
        Gets the given entry in the object.

        Params:
            key = The key to query.

        Returns:
            The $(D DataNode) with the given key.
    */
    ref TValue opIndex()(auto ref TKey key) {
        ptrdiff_t idx = findEntry(key);
        assert(idx >= 0);

        return values[idx].value;
    }

    /**
        Dict-iterator
    */
    int opApply(scope int delegate(size_t i, ref TKey key, ref TValue value) dg) {
        if (!values)
            return 0;
        
        auto dgf = cast(int delegate(size_t i, ref TKey key, ref TValue value) @nogc scope)dg;
        foreach (i; 0..values.length) {
            int result = dgf(i, values[i].key, values[i].value);
            if (result)
                return result;
        }
        return 0;
    }

    /**
        Dict-iterator
    */
    int opApply(scope int delegate(ref TKey key, ref TValue value) dg) {
        if (!values)
            return 0;
        
        auto dgf = cast(int delegate(ref TKey key, ref TValue value) @nogc scope)dg;
        foreach (i; 0..values.length) {
            int result = dgf(values[i].key, values[i].value);
            if (result)
                return result;
        }
        return 0;
    }

    /**
        Dict-iterator
    */
    int opApply(scope int delegate(ref TValue value) dg) {
        if (!values)
            return 0;

        auto dgf = cast(int delegate(ref TValue value) @nogc scope)dg;
        foreach (i; 0..values.length) {
            int result = dgf(values[i].value);
            if (result)
                return result;
        }
        return 0;
    }
}


//
//              IMPLEMENTATION DETAILS
//
private:

/**
    DataNode Key-Value Pair.
*/
struct KV(TKey, TValue) {
@nogc:
    TKey key;
    TValue value;

    pragma(inline, true)
    static void kvassign(T)(ref T dst, ref T src) {
        static if (is(T == string)) {
            dst = src.nu_dup();
        } else static if (is(T == U[], U)) {
            dst = src.nu_dup();
        } else static if (hasElaborateMove!T) {
            dst = src.move();
        } else static if (hasElaborateCopyConstructor!T) {
            dst = T(src);
        } else {
            dst = cast(T)src;
        }
    }

    pragma(inline, true)
    static void kvdelete(T)(ref T dst) {
        static if (hasElaborateDestructor!T) {
            nogc_trydelete(dst);
        } else static if (is(T == U[], U)) {
            nu_freea(dst);
        } else {
            nogc_initialize(dst);
        }
    }

    ~this() nothrow {
        kvdelete(key);
        kvdelete(value);
    }

    this()(auto ref TKey key, auto ref TValue value) @trusted {
        kvassign!TKey(this.key, key);
        kvassign!TValue(this.value, value);
    }

    /// Copy-constructor
    this(ref return scope inout(typeof(this)) rhs) @trusted {
        kvassign!TKey(this.key, cast(TKey)rhs.key);
        kvassign!TValue(this.value, cast(TValue)rhs.value);
    }
}