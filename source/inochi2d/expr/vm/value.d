/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/
module inochi2d.expr.vm.value;
import inochi2d.expr.vm.stack;
import numem.all;

enum InExprValueType {
    NONE,
    number,
    str,
    bytecode,
    nativeFunction,
    returnAddr
}

/**
    Stores the return address and chunk to execute

    TODO: make a bytecode manager interface that makes this safe.
*/
struct InRetPtr {

    /// Bytecode slice
    ubyte[] bc;

    /// Program counter
    uint pc;
}

struct InExprValue {
@nogc:
private:
    InExprValueType type;

public:
    union {
        /// number
        float number;

        /// string
        nstring str;

        /// Executable bytecode
        vector!ubyte bytecode;

        /// Native function
        int function(ref InExprStack stack) func;

        /// Return address
        InRetPtr retptr;
    }

    /**
        Destructor
    */
    ~this() {
        if (type == InExprValueType.str) {
            if (!str.empty) 
                nogc_delete(str);
        }
    }

    /**
        Constructor
    */
    this(float f32) {
        type = InExprValueType.number;
        this.number = f32;
    }

    /**
        Constructor
    */
    this(nstring str) {
        type = InExprValueType.str;
        this.str = str;
    }

    /**
        Constructor
    */
    this(vector!ubyte bytecode) {
        type = InExprValueType.bytecode;
        this.bytecode = bytecode;
    }

    /**
        Constructor
    */
    this(int function(ref InExprStack stack) @nogc func) {
        type = InExprValueType.nativeFunction;
        this.func = func;
    }

    /**
        Constructor
    */
    this(InRetPtr retptr) {
        type = InExprValueType.returnAddr;
        this.retptr = retptr;
    }

    /**
        Get whether the value callable
    */
    bool isCallable() {
        return type == InExprValueType.nativeFunction || type == InExprValueType.bytecode;
    }

    /**
        Get whether the value is a native function
    */
    bool isNativeFunction() {
        return type == InExprValueType.nativeFunction;
    }

    /**
        Get whether the value is a bytecode blob
    */
    bool isBytecodeBlob() {
        return type == InExprValueType.bytecode;
    }

    /**
        Get whether 2 values are compatible
    */
    bool isCompatible(ref InExprValue other) {
        final switch(this.getType()) {
            case InExprValueType.NONE:
                return false;
            case InExprValueType.number:
            case InExprValueType.str:
            case InExprValueType.nativeFunction:
            case InExprValueType.bytecode:
            case InExprValueType.returnAddr:
                return other.getType() == this.getType();
        }
    }

    /**
        Gets whether the value is numeric
    */
    bool isNumeric() {
        return type == InExprValueType.number;
    }

    /**
        Gets the type of the value
    */
    InExprValueType getType() {
        return type;
    }
}