/**
    DataNode abstraction

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.node;
import inp.format.dict;
import inp.format.array;
import nulib.collections;
import numem.core.traits;
import numem.core.meta;
import numem.rc;
import numem;

enum DataNodeType : uint {
    undefined   = 0,
    boolean_    = 1,
    int_        = 2,
    uint_       = 3,
    float_      = 4,
    string_     = 5,
    array_      = 6,
    object_     = 7,
    blob_       = 8,
}

/**
    The compile-time $(D DataNodeType) corrosponding to type $(D T).
*/
template dataNodeTypeOf(T) {
    static if (is(T == bool)) {
        enum dataNodeTypeOf = DataNodeType.boolean_;
    } else static if (__traits(isIntegral, T)) {
        enum dataNodeTypeOf = __traits(isUnsigned, T) ? DataNodeType.uint_ : DataNodeType.int_;
    } else static if (__traits(isFloating, T)) {
        enum dataNodeTypeOf = DataNodeType.float_;
    } else static if (is(T == ubyte[])) {
        enum dataNodeTypeOf = DataNodeType.blob_;
    } else static if (is(T : string)) {
        enum dataNodeTypeOf = DataNodeType.string_;
    } else static if (is(T == U[], U)) {
        enum dataNodeTypeOf = DataNodeType.array_;
    } else static if (is(T == class) || is(T == struct)) {
        enum dataNodeTypeOf = DataNodeType.object_;
    } else {
        enum dataNodeTypeOf = DataNodeType.undefined;
    }
}

/**
    A node containing data for (de)serialization.
*/
struct DataNode {
private:
@nogc:
    import nulib.collections.internal.marray : ManagedArray;
    __gshared DataNode UNDEF = DataNode.init;

    static
    union DataNodeStore {
    @nogc:

        void* undefined;
        bool boolean_;
        long int_; 
        ulong uint_; 
        float float_; 
        string string_;
        RcArray!DataNode array_; 
        RcOrderedDictionary!(string, DataNode) object_;
        ubyte[] blob_;
    }

    DataNodeType dataType = DataNodeType.undefined;
    DataNodeStore dataStore;

    template isSameType(T) {
        enum isSameType(U) = is(T == U);
    }
public:

    /**
        The type of data stored within the node.
    */
    @property DataNodeType type() nothrow pure => dataType;

    /**
        Whether the DataNode contains a nil value.
    */
    @property bool isNull() nothrow pure => dataType == DataNodeType.undefined;

    /**
        Whether the DataNode contains a numeric value.
    */
    @property bool isNumber() nothrow pure => dataType >= DataNodeType.int_ && dataType <= DataNodeType.float_;

    /**
        Whether the DataNode is an object.
    */
    @property bool isObject() nothrow pure => dataType == DataNodeType.object_;

    /**
        Whether the DataNode is an array.
    */
    @property bool isArray() nothrow pure => dataType == DataNodeType.array_;

    /**
        Whether the DataNode is a byte blob.
    */
    @property bool isBlob() nothrow pure => dataType == DataNodeType.blob_;

    /**
        The text content of the node, or null.
    */
    @property string text() nothrow pure => isType(DataNodeType.string_) ? dataStore.string_[] : null;

    /**
        A blob of binary data, or null.
    */
    @property ubyte[] blob() nothrow pure => isType(DataNodeType.blob_) ? dataStore.blob_[] : null;

    /**
        The boolean content of the datanode, or false.
    */
    @property bool boolean() nothrow pure => tryCoerce!bool(false);

    /**
        The number content of the data node, or NaN
    */
    @property float number() nothrow pure => tryCoerce!float(float.nan);

    /**
        The key-value pairs in the DataNode object, or null.
    */
    @property ref RcOrderedDictionary!(string, DataNode) object() nothrow pure => dataStore.object_;

    /**
        The array in the DataNode object, or null.
    */
    @property ref RcArray!DataNode array() nothrow pure => dataStore.array_;

    /// Destructor
    ~this() @trusted nothrow {
        switch(dataType) {
            default:
                this.dataType = DataNodeType.undefined;
                break;
            
            case DataNodeType.string_:
                this.dataType = DataNodeType.undefined;
                nu_freea(this.dataStore.string_);
                break;
            
            case DataNodeType.blob_:
                this.dataType = DataNodeType.undefined;
                nu_freea(this.dataStore.blob_);
                break;

            case DataNodeType.array_:
                this.dataType = DataNodeType.undefined;
                nogc_trydelete(this.dataStore.array_);
                break;

            case DataNodeType.object_:
                this.dataType = DataNodeType.undefined;
                nogc_trydelete(this.dataStore.object_);
                break;
        }

    }

    /**
        Creates a new object node.
    */
    static DataNode createObject() @trusted nothrow {
        DataNode v;
        v.dataType = DataNodeType.object_;
        v.dataStore.object_ = RcOrderedDictionary!(string, DataNode).make();
        return v;
    }

    /**
        Creates a new array node.
    */
    static DataNode createArray() @trusted nothrow {
        DataNode v;
        v.dataType = DataNodeType.array_;
        v.dataStore.array_ = RcArray!(DataNode).make();
        return v;
    }
    
    /**
        Constructs a boolean data node.
    */
    this(T)(auto ref T value) @safe nothrow 
    if (is(T == bool)) {
        this.dataType = DataNodeType.boolean_;
        this.dataStore = DataNodeStore(boolean_: cast(bool)value);
    }
    
    /**
        Constructs a signed integer data node.
    */
    this(T)(auto ref T value) @safe nothrow 
    if (anySatisfy!(isSameType!T, AliasSeq!(byte, short, int, long))) {
        this.dataType = DataNodeType.int_;
        this.dataStore = DataNodeStore(int_: cast(long)value);
    }
    
    /**
        Constructs an unsigned integer data node.
    */
    this(T)(auto ref T value) @safe nothrow 
    if (anySatisfy!(isSameType!T, AliasSeq!(ubyte, ushort, uint, ulong))) {
        this.dataType = DataNodeType.uint_;
        this.dataStore = DataNodeStore(uint_: cast(ulong)value);
    }

    /**
        Constructs a floating point data node.
    */
    this(T)(auto ref T value) @safe nothrow 
    if (anySatisfy!(isSameType!T, AliasSeq!(float, double))) {
        this.dataType = DataNodeType.float_;
        this.dataStore = DataNodeStore(float_: cast(double)value);
    }

    /**
        Constructs a string data node.
    */
    this()(auto ref string value) @safe nothrow {
        this.dataType = DataNodeType.string_;
        this.dataStore = DataNodeStore(string_: value.nu_dup());
    }

    /**
        Constructs a string data node.
    */
    this()(auto ref ubyte[] value) @safe nothrow {
        this.dataType = DataNodeType.blob_;
        this.dataStore = DataNodeStore(blob_: value.nu_dup());
    }

    /**
        Copy constructor
    */
    this()(ref return scope typeof(this) rhs) @trusted {
        this.dataType = rhs.dataType;
        switch(rhs.dataType) {
            case DataNodeType.string_:
                this.dataStore.string_ = cast(typeof(dataStore.string_))rhs.dataStore.string_.nu_dup();
                break;

            case DataNodeType.blob_:
                this.dataStore.blob_ = cast(typeof(dataStore.blob_))rhs.dataStore.blob_.nu_dup();
                break;
            
            case DataNodeType.array_:
                this.dataStore.array_ = cast(typeof(dataStore.array_))rhs.dataStore.array_;
                break;
            
            case DataNodeType.object_:
                this.dataStore.object_ = cast(typeof(dataStore.object_))rhs.dataStore.object_;
                break;
            
            default:
                this.dataStore = cast(typeof(dataStore))rhs.dataStore;
                break;
        }
    }

    /**
        Coerces the value of the DataNode to the given type, if possible.
    */
    T tryCoerce(T)(T defaultValue = T.init) nothrow pure {
        switch(dataType) {
            case DataNodeType.string_:
                static if (is(T == string))
                    return dataStore.string_;
                else
                    return defaultValue;
            
            case DataNodeType.uint_:
                static if (isNumeric!T)
                    return cast(T)dataStore.uint_;
                else
                    return defaultValue;
            
            case DataNodeType.int_:
                static if (isNumeric!T)
                    return cast(T)dataStore.int_;
                else
                    return defaultValue;
            
            case DataNodeType.float_:
                static if (isNumeric!T)
                    return cast(T)dataStore.float_;
                else
                    return defaultValue;
            
            default:
                return defaultValue;
        }
    }

    /**
        Gets whether this DataNode contains data of the given type.

        Params:
            type = The type to check for.
        
        Returns:
            $(D true) if the type of the data in the node matches,
            $(D false) otherwise.
    */
    bool isType(inout(DataNodeType) type) inout nothrow pure => this.dataType == type;

    /**
        Length of the node.
    */
    @property size_t length() {
        switch(dataType) {
            case DataNodeType.array_:
                return dataStore.array_.length;
            case DataNodeType.object_:
                return dataStore.object_.length;
            case DataNodeType.string_:
                return dataStore.string_.length;
            default:
                return 0;
        }
    }

    /**
        Removes the given key from the object.

        Params:
            key = The key to remove.
    */
    void remove(string key) {
        if (this.isType(DataNodeType.object_)) {
            dataStore.object_.remove(key);
        }
    }

    /**
        Removes the given index from the array.

        Params:
            idx = The index to remove.
    */
    void remove(size_t idx) {
        if (this.isType(DataNodeType.array_)) {
            dataStore.array_.remove(idx);
        }
    }

    /**
        Adds the given entry into the array.

        Params:
            rhs = Value to append
    */
    void opOpAssign(string op)(DataNode rhs)
    if (op == "~") {
        if (this.isType(DataNodeType.array_)) {
            dataStore.array_.opOpAssign!op(rhs);
        }
    }

    /**
        Assigns an element of the object node.

        Params:
            key = The key to query.
            value = The value to set.
    */
    void opIndexAssign(T)(auto ref T value, string key) {
        if (this.isType(DataNodeType.object_)) {
            static if (is(T == DataNode)) {
                dataStore.object_.opIndexAssign(value, key);
            } else {
                dataStore.object_.opIndexAssign(DataNode(value), key);
            }
        }
    }

    /**
        Assigns an element of the array node.

        Params:
            rhs = The value to set.
            idx = The idx to set.
    */
    void opIndexAssign(T)(auto ref T rhs, size_t idx) {
        if (this.isType(DataNodeType.array_)) {
            dataStore.array_.opIndexAssign!T(rhs, idx);
        }
    }

    /**
        Gets whether the given key is present in the object.

        Params:
            key = The key to query.

        Returns:
            $(D true) if the object contains a value with the given key,
            $(D false) otherwise.
    */
    inout(DataNode)* opBinaryRight(string op)(string key) inout nothrow
    if (op == "in") {
        return this.isType(DataNodeType.object_) ? key in dataStore.object_ : null;
    }

    /**
        Gets the given entry in the object.

        Params:
            key = The key to query.

        Returns:
            The $(D DataNode) with the given key.
    */
    ref DataNode opIndex(string key) {
        return dataStore.object_.opIndex(key);
    }

    /**
        Gets the given entry in the array.

        Params:
            idx = The index to query.

        Returns:
            The $(D DataNode) with the given index.
    */
    ref DataNode opIndex(size_t idx) {
        return dataStore.array_.opIndex(idx);
    }

    bool opEquals(DataNode other) {
        if (dataType == DataNodeType.int_ && other.dataType == DataNodeType.uint_) {
            return dataStore.int_ >= 0 ? cast(uint)dataStore.int_ == other.dataStore.uint_ : false;
        } else if (dataType == DataNodeType.uint_ && other.dataType == DataNodeType.int_) {
            return other.dataStore.int_ >= 0 ? dataStore.uint_ == cast(uint)other.dataStore.int_ : false;
        }

        if (dataType != other.dataType) {
            return false;
        }

        switch (dataType) {
            case DataNodeType.undefined:
                return dataStore.undefined == other.dataStore.undefined;
            case DataNodeType.boolean_:
                return dataStore.boolean_ == other.dataStore.boolean_;
            case DataNodeType.int_:
                return dataStore.int_ == other.dataStore.int_;
            case DataNodeType.uint_:
                return dataStore.uint_ == other.dataStore.uint_;
            case DataNodeType.float_:
                return dataStore.float_ == other.dataStore.float_;
            case DataNodeType.string_:
                return dataStore.string_ == other.dataStore.string_;
            // case DataNodeType.array_:
            //     return dataStore.array_ == other.dataStore.array_;
            // case DataNodeType.object_:
            //     return dataStore.object_ == other.dataStore.object_;
            case DataNodeType.blob_:
                return dataStore.blob_ == other.dataStore.blob_;
            default:
                return false;
        }
    }

    bool opEquals(T)(T other) {
        static if (__traits(isIntegral, T)) {
            if (dataType == DataNodeType.int_ && dataNodeTypeOf!T == DataNodeType.uint_) {
                return dataStore.int_ >= 0 ? cast(uint)dataStore.int_ == other : false;
            } else if (dataType == DataNodeType.uint_ && dataNodeTypeOf!T == DataNodeType.int_) {
                return other >= 0 ? dataStore.uint_ == cast(uint)other : false;
            }
        }

        if (dataType != dataNodeTypeOf!T) {
            return false;
        }

        // TODO: handle array & dictionary
        static if (dataNodeTypeOf!T == DataNodeType.undefined) {
            return dataStore.undefined == other;
        } else static if (dataNodeTypeOf!T == DataNodeType.boolean_) {
            return dataStore.boolean_ == other;
        } else static if (dataNodeTypeOf!T == DataNodeType.int_) {
            return dataStore.int_ == other;
        } else static if (dataNodeTypeOf!T == DataNodeType.uint_) {
            return dataStore.uint_ == other;
        } else static if (dataNodeTypeOf!T == DataNodeType.float_) {
            return dataStore.float_ == other;
        } else static if (dataNodeTypeOf!T == DataNodeType.string_) {
            return dataStore.string_ == other;
        } else static if (dataNodeTypeOf!T == DataNodeType.blob_) {
            return dataStore.blob_ == other;
        } else {
            return false;
        }
    }

    /**
        Converts the DataNode to a string.
    */
    string toString() const @trusted pure nothrow {
        import nulib.conv : to_string;
        final switch(dataType) {
            
            case DataNodeType.string_:
                return dataStore.string_;
            
            case DataNodeType.boolean_:
                return dataStore.boolean_ ? "true" : "false";
            
            case DataNodeType.int_:
                return to_string(dataStore.int_);
            
            case DataNodeType.uint_:
                return to_string(dataStore.uint_);
            
            case DataNodeType.float_:
                return to_string(dataStore.float_);
            
            case DataNodeType.array_:
                return "<array>";
            
            case DataNodeType.object_:
                return "<object>";
            
            case DataNodeType.blob_:
                return "<blob>";
            
            case DataNodeType.undefined:
                return "<undefined>";
        }
    }
}

@("Create node.")
unittest {
    DataNode n = DataNode.createObject();
    n["a"] = 42;

    assert(n["a"].number == 42);
    n.remove("a");
    assert("a" !in n);
}