/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.io.inp.node;
import numem.all;


/**
    Enumeration over Inochi2D InpNode content types
*/
enum InpNodeType {
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

    InpNodes own the memory of their elements
*/
@AllowInitEmpty
struct InpNode {
@nogc:
private:
    InpNodeType type;
    union {
        nstring str;
        float number;
        bool boolean;
        map!(nstring, InpNode*) node;
        vector!(InpNode*) array;
        vector!ubyte blob;
    }

    void clear() {
        final switch(type) {

            // Destroyed with the node
            case InpNodeType.number:
            case InpNodeType.boolean:
            case InpNodeType.nil:
                break;

            case InpNodeType.str:
                nogc_delete(str);
                break;
                
            case InpNodeType.node:
                nogc_delete(node);
                break;
                
            case InpNodeType.array:
                nogc_delete(array);
                break;
                
            case InpNodeType.blob:
                nogc_delete(blob);
                break;
                
        }
        this.type = InpNodeType.nil;
    }

public:

    /**
        Creates a new object
    */
    static InpNode* createObject() {
        InpNode* node = nogc_new!InpNode;
        node.type = InpNodeType.node;
        return node;
    }

    /**
        Creates a new array
    */
    static InpNode* createArray() {
        InpNode* node = nogc_new!InpNode;
        node.type = InpNodeType.array;
        return node;
    }

    /**
        Creates a new blob
    */
    static InpNode* createBlob(vector!ubyte data) {
        InpNode* node = nogc_new!InpNode;
        node.type = InpNodeType.blob;
        node.blob = vector!ubyte(data);
        return node;
    }

    /**
        Destructor
    */
    ~this() {
        this.clear();
    }

    /**
        Assignment operator
    */
    auto opAssign(nstring value) {
        if (this.isValid()) {
            this.clear();
        }

        // Copy text out
        this.type = InpNodeType.str;
        this.str = nstring(value);
        return this;
    }

    /**
        Assignment operator
    */
    auto opAssign(bool value) {
        if (this.isValid()) {
            this.clear();
        }

        // Copy text out
        this.type = InpNodeType.boolean;
        this.boolean = value;
        return this;
    }

    /**
        Assignment operator
    */
    auto opAssign(float value) {
        if (this.isValid()) {
            this.clear();
        }

        // Copy text out
        this.type = InpNodeType.number;
        this.number = value;
        return this;
    }

    /**
        Index node by key
    */
    auto opIndex(nstring key) {
        if (type != InpNodeType.node) return null;
        if (key !in node) return null;
        
        return node[key];
    }

    /**
        Assign node element by key (static slice)
    */
    auto opIndexAssign(InpNode* node, string key) {
        return this.opIndexAssign(node, nstring(key));
    }

    /**
        Assign node element by key
    */
    auto opIndexAssign(InpNode* node, nstring key) {
        if (type != InpNodeType.node) return null;
        if (node is null) {
            this.node.remove(key);
            return null;
        }

        this.node[key] = node;
        return this.node[key];
    }

    /**
        Index node by index
    */
    auto opIndex(size_t index) {
        if (type != InpNodeType.array) return null;
        if (index >= array.size()) return null;

        return array[index];
    }

    /**
        Array append
    */
    void opOpAssign(string op: "~", T)(T value) {
        if (type != InpNodeType.array) return;
        
        static if (is(value : InpNode*)) {
            array ~= value;
        } else {
            InpNode* nvalue = nogc_new!InpNode;
            nvalue = value;
            array ~= nvalue;
        }
    }

    /**
        Gets the binary blob
    */
    vector!(ubyte)* getBlob() {
        if (this.isBlob) 
            return &blob;
        return null;
    }

    /**
        Gets the length (amount of elements) in a node.
    */
    size_t length() {
        switch(type) {
            default:
                return 0;
            case InpNodeType.node:
                return node.length();
            case InpNodeType.array:
                return array.size();
            case InpNodeType.blob:
                return blob.size();
        }
    }

    /**
        Gets whether the node has a length;
        that is to say that the node contains multiple elements.
    */
    bool hasLength() {
        switch(type) {
            default:
                return false;
            case InpNodeType.node:
                return true;
            case InpNodeType.array:
                return true;
            case InpNodeType.blob:
                return true;
        }
    }

    /**
        Gets whether the node is an object
    */
    bool isObject() {
        return type == InpNodeType.node;
    }

    /**
        Gets whether the node is an array
    */
    bool isArray() {
        return type == InpNodeType.array;
    }

    /**
        Gets whether the node is a binary blob of data
    */
    bool isBlob() {
        return type == InpNodeType.blob;
    }

    /**
        Gets whether the node is a number
    */
    bool isNumber() {
        return type == InpNodeType.number;
    }

    /**
        Gets whether the node is a string
    */
    bool isString() {
        return type == InpNodeType.str;
    }

    /**
        Gets whether the node is a boolean
    */
    bool isBoolean() {
        return type == InpNodeType.boolean;
    }

    /**
        Gets whether the node has any valid values
    */
    bool isValid() {
        return type != InpNodeType.nil;
    }
}