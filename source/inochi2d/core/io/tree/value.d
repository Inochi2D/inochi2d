/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.io.tree.value;
import std.traits;
import numem.all;
import numem.core.uuid;


/**
    Enumeration over Inochi2D InTreeValue content types
*/
enum InTreeValueType {
    /**
        Node not instantiated
    */
    nil,

    /**
        Node is string
    */
    str,

    /**
        Node is number
    */
    number,

    /**
        Node is integer
    */
    integer,

    /**
        UUID
    */
    uuid,

    /**
        Node is boolean
    */
    boolean,

    /**
        Node is a key-value container
    */
    node,

    /**
        Node is an array container
    */
    array,

    /**
        Node is a binary blob
    */
    blob
}

/**
    A node in the Puppet tree.

    InTreeValues own the memory of their elements
*/
@AllowInitEmpty
struct InTreeValue {
@nogc:
private:
    InTreeValueType type;
    InTreeValueStore store;
    union InTreeValueStore {
    @nogc:
        nstring str;
        double number;
        long integer;
        bool boolean;
        UUID uuid;
        weak_map!(nstring, InTreeValue*) node;
        weak_vector!(InTreeValue) array;
        vector!ubyte blob;

        void destroy(InTreeValueType type) nothrow {
            final switch(type) {

                // Destroyed with the tree value
                case InTreeValueType.number:
                case InTreeValueType.boolean:
                case InTreeValueType.integer:
                case InTreeValueType.uuid:
                case InTreeValueType.nil:
                    break;

                case InTreeValueType.str:
                    nogc_delete(str);
                    break;
                    
                case InTreeValueType.node:
                    foreach(ref element; node) {
                        nogc_delete(element);
                    }
                    nogc_delete(node);
                    break;
                    
                case InTreeValueType.array:
                    foreach(ref element; array) {
                        nogc_delete(element);
                    }
                    nogc_delete(array);
                    break;
                    
                case InTreeValueType.blob:
                    nogc_delete(blob);
                    break;
                    
            }
        }
    }

    void clear() nothrow {
        store.destroy(type);
        this.type = InTreeValueType.nil;
    }

public:

    this(ref InTreeValue rhs) nothrow {
        this.type = rhs.type;
        final switch(rhs.type) {

            case InTreeValueType.number:
                store.number = rhs.store.number;
                break;

            case InTreeValueType.boolean:
                store.boolean = rhs.store.boolean;
                break;

            case InTreeValueType.integer:
                store.integer = rhs.store.integer;
                break;

            case InTreeValueType.uuid:
                store.uuid = rhs.store.uuid;
                break;

            case InTreeValueType.nil:
                break;

            case InTreeValueType.str:
                store.str = nstring(rhs.store.str);
                break;
                
            case InTreeValueType.node:
                foreach(key; rhs.store.node.byKey()) {
                    store.node[key] = rhs.store.node[key];
                }
                break;
                
            case InTreeValueType.array:
                store.array = weak_vector!(InTreeValue)(rhs.store.array[]);
                break;
                
            case InTreeValueType.blob:
                store.blob = vector!(ubyte)(rhs.store.blob);
                break;
        }
    }

    /**
        Creates a new object
    */
    static InTreeValue newObject() {
        InTreeValue node;
        node.type = InTreeValueType.node;
        return node;
    }

    /**
        Creates a new array
    */
    static InTreeValue newArray() {
        InTreeValue node;
        node.type = InTreeValueType.array;
        return node;
    }

    /**
        Creates a new blob
    */
    static InTreeValue newBlob() {
        InTreeValue node;
        node.type = InTreeValueType.blob;
        return node;
    }

    /**
        Creates a new float
    */
    this(float value) {
        this.type = InTreeValueType.number;
        store.number = value;
    }

    /**
        Creates a new uuid
    */
    this(UUID value) {
        this.type = InTreeValueType.uuid;
        store.uuid = value;
    }

    /**
        Creates a new float
    */
    this(long value) {
        this.type = InTreeValueType.integer;
        store.integer = value;
    }

    /**
        Creates a new boolean
    */
    this(bool value) {
        this.type = InTreeValueType.boolean;
        store.boolean = value;
    }

    /**
        Creates a new string
    */
    this(nstring value) {
        this.type = InTreeValueType.str;
        store.str = value;
    }

    /**
        Creates a new string
    */
    this(string value) {
        this.type = InTreeValueType.str;
        store.str = nstring(value);
    }

    /**
        Creates a new blob
    */
    this(vector!ubyte value) {
        this.type = InTreeValueType.blob;
        store.blob = vector!(ubyte)(value);
    }

    /**
        Destructor
    */
    ~this() nothrow {
        this.clear();
    }

    /**
        Assignment operator
    */
    auto opAssign(nstring value) {
        if (this.isString()) {
            nogc_delete(store.str);
            store.str = nstring(value);
        }
        return this;
    }

    /**
        Assignment operator
    */
    auto opAssign(bool value) {
        if (this.isBoolean()) {
            store.boolean = value;
        }

        return this;
    }

    /**
        Assignment operator
    */
    auto opAssign(float value) {
        if (this.isNumber()) {
            store.number = value;
        }

        return this;
    }

    /**
        Index tree value by key
    */
    ref auto opIndex(string key) {
        return this.opIndex(nstring(key));
    }

    /**
        Index tree value by key
    */
    ref auto opIndex(nstring key) {
        if (type != InTreeValueType.node) return InTreeValue.init;
        if (key !in store.node) return InTreeValue.init;
        
        return *store.node[key];
    }

    /**
        Assign tree value element by key (static slice)
    */
    void opIndexAssign(InTreeValue node, string key) {
        this.opIndexAssign(node, nstring(key));
    }

    /**
        Assign tree value element by key
    */
    void opIndexAssign(InTreeValue node, nstring key) {
        if (this.type != InTreeValueType.node) 
            return;

        // Replacement
        if (key in store.node) {
            store.node.remove(key);
        }
        
        // Removal
        if (node.type == InTreeValueType.nil) 
            return;

        // Addition
        store.node[key] = nogc_new!(InTreeValue)(node);
        return;
    }

    /**
        Index tree value by index
    */
    auto opIndex(size_t index) {
        if (type != InTreeValueType.array) return InTreeValue.init;
        if (index >= store.array.size()) return InTreeValue.init;

        return store.array[index];
    }

    /**
        Assign tree value element by index
    */
    void opIndexAssign(InTreeValue node, size_t index) {
        if (this.type != InTreeValueType.array) 
            return;

        if (index >= store.array.size())
            return;

        store.array[index] = node;
        return;
    }

    /**
        Array append
    */
    void opOpAssign(string op: "~", T)(T value) {
        if (type != InTreeValueType.array) return;
        
        static if (is(value : InTreeValue)) {
            array ~= value;
        } else {
            InTreeValue nvalue;
            nvalue = value;
            store.array ~= nvalue;
        }
    }

    /**
        Gets a reference to the binary blob

        Returns null if the value is not a blob.
    */
    vector!(ubyte)* getBlobRef() {
        if (this.isBlob) 
            return &store.blob;
        return null;
    }

    /**
        Gets a reference to a tree value in the node

        Returns null if the value is not a node.
    */
    InTreeValue* getNodeRef(string key) {
        return getNodeRef(nstring(key));
    }

    /**
        Gets a reference to a tree value in the node

        Returns null if the value is not a node.
    */
    InTreeValue* getNodeRef(nstring key) {
        if (type != InTreeValueType.node) return null;
        if (key !in store.node) return null;
        
        return store.node[key];
    }

    /**
        Gets the value stored in this treevalue.
    */
    T get(T)() {
        final switch(type) {
            case InTreeValueType.node:
            case InTreeValueType.array:
            case InTreeValueType.nil:
                break;

            case InTreeValueType.number:
                static if (isNumeric!T)
                    return cast(T)store.number;
                else
                    break;

            case InTreeValueType.uuid:
                static if (is(T == UUID))
                    return store.uuid;
                else
                    break;

            case InTreeValueType.integer:
                static if (isNumeric!T)
                    return cast(T)store.integer;
                else
                    break;

            case InTreeValueType.boolean:
                static if (isNumeric!T)
                    return cast(T)store.boolean;
                else static if (is(T == bool))
                    return cast(T)store.boolean;
                else
                    break;
            
            case InTreeValueType.str:
                
                // Slice
                static if (is(T == string))
                    return cast(string)store.str[];

                // Copy
                else static if (is(T == nstring))
                    return nstring(store.str);
                
                else
                    break;
                
            case InTreeValueType.blob:
                
                // Slice
                static if (is(T == ubyte[]))
                    return store.blob[];

                // Copy
                else static if (is(T == vector!(ubyte)))
                    return vector!(ubyte)(store.blob);

                else
                    break;
        }

        return T.init;
    }

    /**
        Gets the length (amount of elements) in a node.
    */
    size_t getLength() {
        switch(type) {
            default:
                return 0;
            case InTreeValueType.node:
                return store.node.length();
            case InTreeValueType.array:
                return store.array.size();
            case InTreeValueType.blob:
                return store.blob.size();
        }
    }

    /**
        Iterates the node by its keys
    */
    auto byKey() {
        switch(type) {
            case InTreeValueType.node:
                return store.node.byKey();
            default:
                return ReturnType!(store.node.byKey).init;
        }
    }

    /**
        Gets whether the tree value has a length;
        that is to say that the tree value contains multiple elements.
    */
    bool hasLength() {
        switch(type) {
            default:
                return false;
            case InTreeValueType.node:
                return true;
            case InTreeValueType.array:
                return true;
            case InTreeValueType.blob:
                return true;
        }
    }

    /**
        Gets the type of the tree value.
    */
    InTreeValueType getType() {
        return type;
    }

    /**
        Gets whether the tree value is a node
    */
    bool isNode() {
        return type == InTreeValueType.node;
    }

    /**
        Gets whether the tree value is an array
    */
    bool isArray() {
        return type == InTreeValueType.array;
    }

    /**
        Gets whether the tree value is a binary blob of data
    */
    bool isBlob() {
        return type == InTreeValueType.blob;
    }

    /**
        Gets whether the tree value is a number
    */
    bool isNumber() {
        return type == InTreeValueType.number;
    }

    /**
        Gets whether the tree value is a number
    */
    bool isInteger() {
        return type == InTreeValueType.integer;
    }

    /**
        Gets whether the tree value is a string
    */
    bool isString() {
        return type == InTreeValueType.str;
    }

    /**
        Gets whether the tree value is a boolean
    */
    bool isBoolean() {
        return type == InTreeValueType.boolean;
    }

    /**
        Gets whether the tree value has any valid values
    */
    bool isValid() {
        return type != InTreeValueType.nil;
    }
}

@("InTreeValue (number)")
unittest {
    InTreeValue value = 42.0f;
    assert(value.get!float == 42.0f);
}

@("InTreeValue (bool)")
unittest {
    InTreeValue value = false;
    assert(value.get!bool == false);
}

@("InTreeValue (string)")
unittest {
    const string tmp = "Hello, world!";

    InTreeValue value = tmp;
    assert(value.get!string == tmp[]);
    assert(value.get!nstring == nstring(tmp));
}

@("InTreeValue (object)")
unittest {
    const float tmpFloat = 42.0f;
    const bool tmpBool = true;
    const string tmpStr = "Hello, world!";

    // Create object
    InTreeValue object = InTreeValue.newObject();
    object["a"] = InTreeValue(tmpFloat);
    object["b"] = InTreeValue(tmpBool);
    object["c"] = InTreeValue(tmpStr);

    // Check validity
    assert(object.isValid(), "Object not valid!");
    assert(object.isNode(), "Object not an object?!");

    // Check element validity
    assert(object["a"].isValid(), "Number item 'a' returned invalid tree value!");
    assert(object["b"].isValid(), "Boolean item 'b' returned invalid tree value!");
    assert(object["c"].isValid(), "String item 'c' returned invalid tree value!");

    // Check element values
    assert(object["a"].get!float() == tmpFloat, "Number item 'a' return wrong value!");
    assert(object["b"].get!bool() == tmpBool, "Boolean item 'b' return wrong value!");
    assert(object["c"].get!string() == tmpStr, "String item 'c' return wrong value!");
}

@("InTreeValue (object, get invalid)")
unittest {
    InTreeValue object = InTreeValue.newObject();
    assert(object["invalid"].isValid() == false);
}