module inochi2d.core.format.serde.node;
import nulib.data.variant;
import nulib.collections;
import nulib.memory.shared_ptr;
import numem.core.traits;
import numem.core.meta;
import numem;

enum DataNodeType : uint {
    undefined   = 0,
    string_     = 1,
    int_        = 2,
    uint_       = 3,
    float_      = 4,
    array_      = 5,
    object_     = 6
}

/**

*/
struct DataNode {
private:
@nogc:
    import nulib.collections.internal.marray : ManagedArray;

    static
    union DataNodeStore {
    @nogc:

        static
        struct ObjectNode {
        private:
        @nogc:

            static
            struct KV {
            @nogc:
                ~this() {
                    nu_freea(key);
                    nogc_delete(value);
                }

                /// Copy-constructor
                this(ref return scope KV rhs) {
                    this.key = rhs.key.nu_dup();
                    this.value = rhs.value;
                }
            
                string key;
                DataNode value;
            }
            ManagedArray!KV values;

            /// Helper that finds an entry by its key.
            pragma(inline, true)
            ptrdiff_t findEntry(string key) const nothrow {
                foreach(i, ref entry; values) {
                    if (entry.key == key)
                        return i;
                }
                return -1;
            }

        public:

            /// Destructor
            ~this() {
                values.resize(0);
            }

            /**
                Length of the node.
            */
            @property size_t length() => values.length;

            /**
                Removes the given key from the object.

                Params:
                    key = The key to remove.
            */
            void remove(string key) {
                ptrdiff_t idx = findEntry(key);
                if (idx >= 0) {
                    values.deleteRange(values[idx..idx+1]);
                }
            }

            /**
                Assigns an element of the object node.

                Params:
                    key = The key to query.
                    value = The value to set.
            */
            void opIndexAssign(T)(T value, string key) {
                ptrdiff_t idx = findEntry(key);
                if (idx >= 0) {
                    nogc_delete(values[idx].value);
                    values[idx].value = DataNode(value);
                    return;
                }

                // Append our new entry.
                values.resize(values.length+1);
                values[$-1] = KV(key.nu_dup, DataNode(value));
            }

            /**
                Gets whether the given key is present in the object.

                Params:
                    key = The key to query.

                Returns:
                    $(D true) if the object contains a value with the given key,
                    $(D false) otherwise.
            */
            bool opBinaryRight(string op)(string key) const nothrow
            if (op == "in") {
                return findEntry(key) != -1;
            }

            /**
                Gets the given entry in the object.

                Params:
                    key = The key to query.

                Returns:
                    The $(D DataNode) with the given key.
            */
            DataNode opIndex(string key) nothrow {
                ptrdiff_t idx = findEntry(key);
                return idx >= 0 ? (values[idx].value) : DataNode.init;
            }
        }

        static
        struct ArrayNode {
        private:
        @nogc:
            ManagedArray!DataNode values;
        
        public:

            /// Destructor
            ~this() {
                values.resize(0);
            }

            /**
                Length of the node.
            */
            @property size_t length() => values.length;

            /**
                Removes the given index from the array.

                Params:
                    idx = The index to remove.
            */
            void remove(size_t idx) {
                if (idx >= values.length)
                    return;
                
                values.deleteRange(values[idx..idx+1]);
            }

            /**
                Adds the given entry into the array.

                Params:
                    rhs = Value to append
            */
            void opOpAssign(string op)(DataNode rhs) nothrow
            if (op == "~") {
                values.resize(values.length+1);
                values[$-1] = rhs;
            }

            /**
                Assigns an element of the array node.

                Params:
                    rhs = The value to set.
                    idx = The idx to set.
            */
            void opIndexAssign(T)(T rhs, size_t idx) {
                if (idx >= values.length)
                    return;
                
                values[idx] = rhs;
            }

            /**
                Gets the given entry in the array.

                Params:
                    idx = The index to query.

                Returns:
                    The $(D DataNode) with the given index.
            */
            DataNode opIndex(size_t idx) nothrow {
                return idx < values.length ? values[idx] : DataNode.init;
            }
        }

        void* undefined;
        string string_;
        long int_; 
        ulong uint_; 
        float float_; 
        ArrayNode array_; 
        ObjectNode object_; 
    }

    DataNodeType dataType = DataNodeType.undefined;
    DataNodeStore dataStore;
public:

    /**
        The type of data stored within the node.
    */
    @property DataNodeType type() nothrow pure => dataType;

    /**
        Whether the DataNode contains a numeric value.
    */
    @property bool isNumber() nothrow pure => dataType >= DataNodeType.int_ && dataType <= DataNodeType.float_;

    /**
        The text content of the node, or null.
    */
    @property string text() nothrow pure => isType(DataNodeType.string_) ? dataStore.string_[] : null;

    /**
        The text content of the node, or null.
    */
    @property float number() nothrow pure => tryCoerce!float(float.nan);

    /// Destructor
    ~this() {
        switch(dataType) {
            default:
                this.dataType = DataNodeType.undefined;
                break;
            
            case DataNodeType.string_:
                nu_freea(this.dataStore.string_);
                break;

            case DataNodeType.array_:
                nogc_delete(this.dataStore.array_);
                break;

            case DataNodeType.object_:
                nogc_delete(this.dataStore.object_);
                break;
        }

    }

    /**
        Creates a new object node.
    */
    static DataNode createObject() {
        DataNode v;
        v.dataType = DataNodeType.object_;
        nogc_initialize(v.dataStore.object_);
        return v;
    }

    /**
        Creates a new array node.
    */
    static DataNode createArray() {
        DataNode v;
        v.dataType = DataNodeType.array_;
        nogc_initialize(v.dataStore.array_);
        return v;
    }

    /**
        Constructs an integer data node.
    */
    static foreach(T; AliasSeq!(byte, short, int, long)) {
        this()(auto ref T value) @safe nothrow {
            this.dataType = DataNodeType.int_;
            this.dataStore = DataNodeStore(int_: cast(long)value);
        }
    }

    /**
        Constructs an unsigned integer data node.
    */
    static foreach(T; AliasSeq!(ubyte, ushort, uint, ulong)) {
        this()(auto ref T value) @safe nothrow {
            this.dataType = DataNodeType.uint_;
            this.dataStore = DataNodeStore(uint_: cast(ulong)value);
        }
    }

    /**
        Constructs a floating point data node.
    */
    static foreach(T; AliasSeq!(float, double)) {
        this()(auto ref T value) @safe nothrow {
            this.dataType = DataNodeType.float_;
            this.dataStore = DataNodeStore(float_: cast(double)value);
        }
    }

    /**
        Constructs a string data node.
    */
    this()(auto ref string value) @safe nothrow {
        this.dataType = DataNodeType.string_;
        this.dataStore = DataNodeStore(string_: value.nu_dup());
    }

    /**
        Copy constructor
    */
    this()(scope auto ref inout(typeof(this)) rhs) {
        this.dataType = rhs.dataType;
        switch(dataType) {
            case DataNodeType.string_:
                this.dataStore.string_ = rhs.dataStore.string_.nu_dup();
                break;
            
            case DataNodeType.array_:
                this.dataStore.array_ = rhs.dataStore.array_.nu_dup();
                break;
            
            case DataNodeType.object_:
                this.dataStore.object_ = rhs.dataStore.object_.nu_dup();
                break;
            
            default:
                this.dataStore = rhs.dataStore;
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
                return dataStore.array_.length;
            case DataNodeType.string_:
                return dataStore.array_.length;
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
    void opOpAssign(string op)(DataNode rhs) nothrow
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
    void opIndexAssign(T)(T value, string key) {
        if (this.isType(DataNodeType.object_)) {
            dataStore.object_.opIndexAssign!T(value, key);
        }
    }

    /**
        Assigns an element of the array node.

        Params:
            rhs = The value to set.
            idx = The idx to set.
    */
    void opIndexAssign(T)(T rhs, size_t idx) {
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
    bool opBinaryRight(string op)(string key) const nothrow
    if (op == "in") {
        return this.isType(DataNodeType.object_) ? dataStore.object_.opBinaryRight!(op)(key) : false;
    }

    /**
        Gets the given entry in the object.

        Params:
            key = The key to query.

        Returns:
            The $(D DataNode) with the given key.
    */
    DataNode opIndex(string key) nothrow {
        return this.isType(DataNodeType.object_) ? dataStore.object_.opIndex(key) : DataNode.init;
    }

    /**
        Gets the given entry in the array.

        Params:
            idx = The index to query.

        Returns:
            The $(D DataNode) with the given index.
    */
    DataNode opIndex(size_t idx) nothrow {
        return this.isType(DataNodeType.array_) ? dataStore.array_.opIndex(idx) : DataNode.init;
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