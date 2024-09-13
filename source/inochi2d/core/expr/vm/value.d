/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/
module inochi2d.core.expr.vm.value;
import inochi2d.core.expr.vm.stack;
import inochi2d.core.expr.vm.vm;
import numem.all;

enum InVmValueType {
    NONE,
    number,
    str,
    bytecode,
    nativeFunction,
    returnAddr
}

struct InVmValue {
@nogc:
private:
    InVmValueType type;

public:
    union {
        /// number
        float number;

        /// string
        nstring str;

        /// Executable bytecode
        vector!ubyte bytecode;

        /// Native function
        int function(ref InVmState state) func;
    }

    /**
        Destructor
    */
    ~this() {
        if (type == InVmValueType.str) {
            if (!str.empty) 
                nogc_delete(str);
        }
    }

    /**
        Constructor
    */
    this(float f32) {
        type = InVmValueType.number;
        this.number = f32;
    }

    /**
        Constructor
    */
    this(nstring str) {
        type = InVmValueType.str;
        this.str = str;
    }

    /**
        Constructor
    */
    this(vector!ubyte bytecode) {
        type = InVmValueType.bytecode;
        this.bytecode = bytecode;
    }

    /**
        Constructor
    */
    this(int function(ref InVmState stack) @nogc func) {
        type = InVmValueType.nativeFunction;
        this.func = func;
    }

    /**
        Get whether the value callable
    */
    bool isCallable() {
        return type == InVmValueType.nativeFunction || type == InVmValueType.bytecode;
    }

    /**
        Get whether the value is a native function
    */
    bool isNativeFunction() {
        return type == InVmValueType.nativeFunction;
    }

    /**
        Get whether the value is a bytecode blob
    */
    bool isBytecodeBlob() {
        return type == InVmValueType.bytecode;
    }

    /**
        Get whether 2 values are compatible
    */
    bool isCompatible(ref InVmValue other) {
        final switch(this.getType()) {
            case InVmValueType.NONE:
                return false;
            case InVmValueType.number:
            case InVmValueType.str:
            case InVmValueType.nativeFunction:
            case InVmValueType.bytecode:
            case InVmValueType.returnAddr:
                return other.getType() == this.getType();
        }
    }

    /**
        Gets whether the value is numeric
    */
    bool isNumeric() {
        return type == InVmValueType.number;
    }

    /**
        Gets the type of the value
    */
    InVmValueType getType() {
        return type;
    }
}