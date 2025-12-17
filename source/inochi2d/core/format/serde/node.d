module inochi2d.core.format.serde.node;
import nulib.data.variant;
import nulib.collections;
import nulib.memory.shared_ptr;
import numem.core.traits;
import numem.core.meta;
import numem;

/**
    A node of data, may contain arrays of data.
*/
struct DataNode {
private:
@nogc:
    // Type handling
    alias BASIC_NODES = AliasSeq!(int, float, string, ubyte, ObjectNode);
    alias ARRAY_NODES = staticMap!(ArrayNode, BASIC_NODES);
    alias ALL_NODES = AliasSeq!(BASIC_NODES, ARRAY_NODES);

    enum ARRAY_ID(size_t i) = BASIC_NODES.length+i;

    template typeIdOf(T) {
        static foreach(i, NT; ALL_NODES) {
            static if (!is(typeof(typeIdOf) == size_t) && isAssignable!(NT, T))
                enum size_t typeIdOf = i;
        }

        static if (!is(typeof(typeIdOf) == size_t))
            enum size_t typeIdOf = -1;
    }

    // Object Layout

    shared_ptr!DataNodeValues data_;
protected:

    //
    //              Sub-types
    //

    import nulib.collections.internal.marray : ManagedArray;

    static
    struct ArrayNode(T) {
    private:
    @nogc:
        ManagedArray!T values;
        
    public:

        /**
            Length of the node.
        */
        @property size_t length() => values.length;

        /**
            Allows appending to array nodes.
        */
        auto ref opOpAssign(string op, T)(T value)
        if (op == "~") {
            values.resize(values.length+1);
            values[$-1] = DataNode(value);
            return this;
        }

        void remove(size_t idx) {
            if (idx >= values.length)
                return;
            
            values.deleteRange(values[idx..idx+1]);
        }
    }

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

            Returns:
                A $(D Variant) pointer if the object contains the entry,
                $(D null) otherwise. 
        */
        auto ref opIndexAssign(T)(T value, string key) {
            ptrdiff_t idx = findEntry(key);
            if (idx >= 0) {
                nogc_delete(values[idx].value);
                values[idx].value = DataNode(value);
                return value;
            }

            // Append our new entry.
            values.resize(values.length+1);
            values[$-1] = KV(key.nu_dup, DataNode(value));
            return value;
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
    struct DataNodeValues {
    public:
    @nogc:
        static
        union Values {
        @nogc:
            static foreach(int i, T; ALL_NODES) {
                mixin("T value", i.stringof, ";");
            }
        }

        uint type;
        Values data;

        // Length helper
        @property size_t length() {
            switch(type) {
                static foreach(i, T; ALL_NODES) {
                    case i:
                        static if (is(typeof(() => T.init.length)))
                            return data.tupleof[i].length;
                        else
                            return 0;
                }
                default:
                    return 0;
            }
        }

        this(T)(T value) {
            this.type = typeIdOf!T;
            static if (is(T == string)) {
                this.data.tupleof[typeIdOf!string] = value.nu_dup();
            } else {
                this.data.tupleof[typeIdOf!T] = value;
            }
        }

        ~this() {
            static foreach(i, T; ALL_NODES) {
                static if (is(T == string)) {
                    if (type == typeIdOf!string)
                        nu_freea(data.tupleof[i]);
                } else {
                    if (type == typeIdOf!T)
                        nogc_delete(data.tupleof[i]);
                }
            }
        }
    }
public:

    /**
        Whether the node contains data of the given type.
    */
    pragma(inline, true)
    @property bool isType(T)() => data_.isValid && (data_.type == typeIdOf!T);

    /**
        Whether the node contains no data.
    */
    pragma(inline, true)
    @property bool isUndefined() => !data_.isValid;

    /**
        Whether the node contains a number.
    */
    pragma(inline, true)
    @property bool isNumber() nothrow => isType!float || isType!int;

    /**
        Whether the node contains an integer.
    */
    pragma(inline, true)
    @property bool isIntegral() nothrow => isType!int();

    /**
        Whether the node contains a string.
    */
    pragma(inline, true)
    @property bool isText() nothrow => isType!string();

    /**
        Whether the node contains a byte.
    */
    pragma(inline, true)
    @property bool isByte() nothrow => isType!ubyte();

    /**
        Whether the node contains an array.
    */
    pragma(inline, true)
    @property bool isObject() nothrow => isType!ObjectNode;

    /**
        Whether the node contains an array.
    */
    pragma(inline, true)
    @property bool isArray() nothrow => data_.isValid && data_.type >= ARRAY_ID!0;
    
    /**
        The number value of the node.
    */
    @property float number() => isNumber ? (isIntegral ? cast(float)data_.data.tupleof[typeIdOf!int] : data_.data.tupleof[typeIdOf!float]) : float.nan;

    /**
        The integral value of the node
    */
    @property int integral() => isIntegral ? data_.data.tupleof[typeIdOf!int] : 0;

    /**
        The text value of the node.
    */
    @property string text() => isText ? data_.data.tupleof[typeIdOf!string] : null;

    /**
        Gets the sub-array stored in the $(D DataNode)
    */
    @property T[] array(T)()
    if (typeIdOf!T >= 0) {
        if (!isArray)
            return T.init;

        return data_.data.tupleof[ARRAY_ID!(typeIdOf!T)].values;
    }

    /**
        Length of the node, if it's an array or object.
    */
    @property size_t length() => data_.isValid ? data_.length : 0;

    /// Destructor
    ~this() {
        nogc_delete(data_);
    }

    /// Copy-constructor
    this(ref return scope DataNode rhs) {
        this.data_ = rhs.data_;
    }

    /**
        Creates a new object data node.
    */
    static DataNode createObject() {
        DataNode v;
        v.data_ = shared_new!DataNodeValues(ObjectNode());
        return v;
    }
    
    /**
        Creates a new array data node.
    */
    static DataNode createArrayOf(T)()
    if (typeIdOf!T >= 0) {
        DataNode v;
        v.data_ = shared_new!DataNodeValues(ArrayNode!T());
        return v;
    }

    static foreach(T; BASIC_NODES) {

        /**
            Constructs a basic DataNode.

            Params:
                value = The initial value of the node.
        */
        this(T value) {
            this.data_ = shared_new!DataNodeValues(value);
        }
    }

    /**
        Removes the given key from the array.

        Params:
            key = The key to remove.
    */
    void remove(string key) {
        if (!isObject)
            return;

        data_.data.tupleof[typeIdOf!ObjectNode].remove(key);
    }

    /**
        Removes the given key from the array.

        Params:
            idx = The index to remove.
    */
    void remove(size_t idx) {
        if (!isArray)
            return;

        switch_: switch(data_.type) {
            default: break switch_;
            
            static foreach(i, T; ARRAY_NODES) {
                case ARRAY_ID!i:
                    data_.data.tupleof[ARRAY_ID!i].remove(idx);
                    break switch_;
            }
        }
    }
    /**
        Gets an a $(D DataNode) associated with a key, if this is an object.

        Params:
            key = The key to query.
    */
    auto ref opIndex(string key) {
        if (!isObject)
            return DataNode.init;
        
        return data_.data.tupleof[typeIdOf!ObjectNode].opIndex(key);
    }

    /**
        Assigns a specific element of the data node.

        Params:
            idx = The index to set, must be within range.
            value = The value to set.

        Returns:
            A $(D Variant) pointer if the object contains the entry,
            $(D null) otherwise. 
    */
    auto ref opIndexAssign(T)(T value, size_t idx) {
        if (!isArray)
            return value;

        switch(data_.type) {
            default:
                return value;
            
            static foreach(i, T; ARRAY_NODES) {
                case ARRAY_ID!i:
                    if (idx >= data_.data.tupleof[ARRAY_ID!i].length)
                        return value;
                    
                    data_.data.tupleof[ARRAY_ID!i][idx] = value;
                    return value;
            }
        }
    }

    /**
        Assigns a specific element of the data node.

        Params:
            key = The key to set.
            value = The value to set.

        Returns:
            A $(D Variant) pointer if the object contains the entry,
            $(D null) otherwise. 
    */
    auto ref opIndexAssign(T)(T value, string key) {
        if (!isObject)
            return value;

        data_.data.tupleof[typeIdOf!ObjectNode].opIndexAssign!T(value, key);
        return value;
    }

    /**
        Gets whether the given key is present in the DataNode, if it's an object..

        Params:
            key = The key to query.

        Returns:
            $(D true) if the object contains a value with the given key,
            $(D false) otherwise.
    */
    bool opBinaryRight(string op)(string key) nothrow
    if (op == "in") {
        return isObject ? data_.data.tupleof[typeIdOf!ObjectNode].opBinaryRight!(op)(key) : false;
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