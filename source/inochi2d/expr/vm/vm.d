/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.expr.vm.vm;
import inochi2d.expr.vm.value;
import inochi2d.expr.vm.opcodes;
import inochi2d.expr.vm.stack;
import numem.all;
import std.string;


/**
    Local execution state
*/
struct InExprVMState {
@nogc:

    // Stack
    InExprStack stack;

    /// Bytecode being executed
    ubyte[] bc;

    /// Program counter
    uint pc;

    /// Current operation flag
    ubyte flags;

    /// Get if the previous CMP flag was set to Equal
    bool flagEq() {
        return (flags & InExprVMFlag.eq) != 0;
    }

    /// Get if the previous CMP flag was set to Below
    bool flagBelow() {
        return (flags & InExprVMFlag.below) != 0;
    }

    /// Get if the previous CMP flag was set to Above
    bool flagAbove() {
        return flags == 0;
    }
}

enum InExprVMFlag : ubyte {
    /// Equal flag (zero flag)
    eq          = 0b0000_0001,

    /// Below flag (carry flag)
    below       = 0b0000_0010,

    /// Invalid operation flag.
    invalidOp   = 0b0001_0000,
}

/**
    A execution environment
*/
abstract
class InExprExecutor {
@nogc:
private:
    InExprVMState state;

    void _vmcmp(T)(T lhs, T rhs) {
        state.flags = 0;

        if (lhs == rhs) state.flags |= InExprVMFlag.eq;
        if (lhs < rhs)  state.flags |= InExprVMFlag.below;
    }

    struct _vmGlobalState {
        map!(nstring, InExprValue) globals;
    }

protected:

    /**
        Gets the local execution state
    */
    final
    InExprVMState getState() {
        return state;
    }

    /**
        Gets the global execution state
    */
    abstract _vmGlobalState* getGlobalState();

    /**
        Jumps to the specified address.
    */
    final
    void jump(size_t offset) {
        if (offset >= state.pc) return;
        state.pc = cast(uint)offset;
    }

    /**
        Runs a single instruction
    */
    final
    bool runOne() {
        import core.stdc.stdio : printf;
        InExprOpCode opcode = cast(InExprOpCode)state.bc[state.pc++];
        
        switch(opcode) {
            default:
                return false;

            case InExprOpCode.NOP:
                return true;
            
            case InExprOpCode.ADD:
                InExprValue* rhsp = state.stack.peek(0);
                InExprValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InExprValue rhs = *rhsp;
                InExprValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    state.stack.pop(2);
                    state.stack.push(lhs.number + rhs.number);
                }
                return false;
            
            case InExprOpCode.SUB:
                InExprValue* rhsp = state.stack.peek(0);
                InExprValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InExprValue rhs = *rhsp;
                InExprValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    state.stack.pop(2);
                    state.stack.push(lhs.number - rhs.number);
                }
                return false;
            
            case InExprOpCode.MUL:
                InExprValue* rhsp = state.stack.peek(0);
                InExprValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InExprValue rhs = *rhsp;
                InExprValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    state.stack.pop(2);
                    state.stack.push(lhs.number * rhs.number);
                }
                return false;
            
            case InExprOpCode.DIV:
                InExprValue* rhsp = state.stack.peek(0);
                InExprValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InExprValue rhs = *rhsp;
                InExprValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    state.stack.pop(2);
                    state.stack.push(lhs.number / rhs.number);
                }
                return false;
            
            case InExprOpCode.MOD:
                InExprValue* rhsp = state.stack.peek(0);
                InExprValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InExprValue rhs = *rhsp;
                InExprValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    import inmath.math : fmodf;
                    state.stack.pop(2);
                    state.stack.push(fmodf(lhs.number, rhs.number));
                }
                return false;
            
            case InExprOpCode.NOT:
                InExprValue* lhsp = state.stack.peek(0);
                if (!lhsp) 
                    return false;
                
                InExprValue lhs = *lhsp;

                if (lhs.isNumeric) {
                    state.stack.pop(1);
                    state.stack.push(-lhs.number);
                }
                return false;

            case InExprOpCode.PUSH_n:
                ubyte[4] val = state.bc[state.pc..state.pc+4];
                float f32 = fromEndian!float(val, Endianess.littleEndian);
                state.stack.push(f32);
                state.pc += 4;
                return true;

            case InExprOpCode.PUSH_s:
                ubyte[4] val = state.bc[state.pc..state.pc+4];
                state.pc += 4;

                uint length = fromEndian!uint(val, Endianess.littleEndian);
                
                // Invalid string.
                if (state.pc+length >= state.bc.length)
                    return false;

                nstring nstr = cast(string)state.bc[state.pc..state.pc+length];
                state.stack.push(nstr);

                state.pc += length;
                return true;

            case InExprOpCode.POP:
                ptrdiff_t offset = state.bc[state.pc++];
                ptrdiff_t count = state.bc[state.pc++];
                state.stack.pop(offset, count);
                return true;

            case InExprOpCode.PEEK:
                ptrdiff_t offset = state.bc[state.pc++];
                state.stack.push(*state.stack.peek(offset));
                return true;

            case InExprOpCode.CMP:
                state.flags = InExprVMFlag.invalidOp;

                InExprValue* rhs = state.stack.peek(0);
                InExprValue* lhs = state.stack.peek(1);

                if (lhs.isNumeric && rhs.isNumeric) {
                    _vmcmp(lhs.number, rhs.number);
                }
                return false;

            case InExprOpCode.JMP:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                this.jump(addr);
                return true;

            case InExprOpCode.JEQ:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagEq())
                    this.jump(addr);
                return true;

            case InExprOpCode.JNQ:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (!state.flagEq())
                    this.jump(addr);
                return true;

            case InExprOpCode.JL:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagBelow())
                    this.jump(addr);
                return true;

            case InExprOpCode.JLE:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagBelow() || state.flagEq())
                    this.jump(addr);
                return true;

            case InExprOpCode.JG:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagAbove())
                    this.jump(addr);
                return true;

            case InExprOpCode.JGE:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagAbove() || state.flagEq())
                    this.jump(addr);
                return true;

            case InExprOpCode.JSR:

                // Get information
                ptrdiff_t passed = state.bc[state.pc++];
                InExprValue* func = state.stack.pop();

                if (passed >= state.stack.getMaxDepth()) return false;
                if (!func || !func.isCallable()) return false;

                if (func.isNativeFunction()) {

                    func.func(state.stack);

                } else {

                    // Store return pointer
                    InRetPtr retptr;
                    retptr.pc = state.pc;
                    retptr.bc = state.bc;

                    state.stack.insert(InExprValue(retptr), passed);
                    this.state.pc = 0;
                    this.state.bc = func.bytecode[];
                }
                return true;

            case InExprOpCode.RET:
                ptrdiff_t returnValues = state.bc[state.pc];
                ptrdiff_t stackDepth = cast(ptrdiff_t)state.stack.getDepth();
                
                // CASE: Return to host
                if (stackDepth-returnValues == 0) {
                    return false;
                }

                // Return to caller
                InExprValue* rptr = state.stack.peek(returnValues);
                if (!rptr || rptr.getType() != InExprValueType.returnAddr) return false;
                this.state.pc = rptr.retptr.pc;
                this.state.bc = rptr.retptr.bc;
                return true;

            case InExprOpCode.SETG:
                InExprValue* name = state.stack.pop();
                InExprValue* item = state.stack.pop();

                if (name && item && name.getType() == InExprValueType.str) {
                    state.stack.pop(2);

                    this.getGlobalState().globals[name.str] = *item;
                    return true;
                }
                return false;
                
            case InExprOpCode.GETG:
                InExprValue* name = state.stack.pop();
                if (name && name.getType() == InExprValueType.str) {

                    if (name.str in this.getGlobalState().globals) {
                        state.stack.push(this.getGlobalState().globals[name.str]);
                        return true;
                    }
                }
                return false;


        }
    }

    /**
        Runs code

        Returns the depth of the stack on completion.
    */
    size_t run() {
        while(this.runOne()) { }
        return state.stack.getDepth();
    }

    this() {
        state.stack = nogc_new!InExprStack();
    }

public:

    /**
        Gets global value
    */
    InExprValue* getGlobal(nstring name) {
        if (name in getGlobalState().globals) {
            return &getGlobalState().globals[name];
        }
        return null;
    }

    /**
        Sets global value
    */
    void setGlobal(nstring name, InExprValue value) {
        getGlobalState().globals[name] = value;
    }

    /**
        Pushes a float to the stack
    */
    final
    void push(float f32) {
        state.stack.push(f32);
    }

    /**
        Pushes a string to the stack
    */
    final
    void push(nstring str) {
        state.stack.push(str);
    }
    
    /**
        Pushes a ExprValue to the stack
    */
    final
    void push(InExprValue val) {
        state.stack.push(val);
    }

    /**
        Pops a ExprValue from the stack
    */
    final
    InExprValue peek(ptrdiff_t offset) {
        InExprValue v;

        auto p = state.stack.peek(offset);
        if (p) {
            v = *p;
        }

        return v;
    }

    /**
        Pops a ExprValue from the stack
    */
    final
    InExprValue pop() {
        InExprValue v;

        auto p = state.stack.peek(0);
        if (p) {
            v = *state.stack.pop();
        }

        return v;
    }

    /**
        Gets depth of stack
    */
    final
    size_t getStackDepth() {
        return state.stack.getDepth();
    }
}

class InExprVM : InExprExecutor {
@nogc:
private:
    shared_ptr!_vmGlobalState globalState;

protected:
    override
    _vmGlobalState* getGlobalState() {
        return globalState.get();
    }

public:
    this() {
        this.globalState = shared_new!_vmGlobalState;
    }

    /**
        Executes code in global scope.

        Returns size of stack after operation.
    */
    int execute(ubyte[] bytecode) {
        state.bc = bytecode;
        state.pc = 0;

        // Run and get return values
        size_t rval = run();

        // Reset code and program counter.
        state.pc = 0;
        state.bc = null;
        return cast(int)rval;
    }

    /**
        Calls a global function

        Returns return value count.
        Returns -1 on error.
    */
    int call(nstring gfunc) {
        InExprValue* v = this.getGlobal(gfunc);
        if (v && v.isCallable()) {
            if (v.isNativeFunction()) {
                return v.func(state.stack);
            } else {
                size_t rval = execute(v.bytecode[]);
                return cast(int)rval;
            }
        }
        return -1;
    }

    /**
        Dumps stack to stdout
    */
    void dumpStack() {
        state.stack.dumpStack();
    }
}


//
//      UNIT TESTS
//

import inochi2d.expr.vm.builder : InExprBytecodeBuilder;

@("VM: NATIVE CALL")
unittest {
    import inmath.math : sin;

    // Sin function
    static int mySinFunc(ref InExprStack stack) @nogc {
        InExprValue* v = stack.pop();
        if (v && v.isNumeric) {
            stack.push(sin(v.number));
            return 1;
        }
        return 0;
    }

    // Instantiate VM
    InExprVM vm = new InExprVM();
    vm.setGlobal(nstring("sin"), InExprValue(&mySinFunc));

    vm.push(1.0);
    int retValCount = vm.call(nstring("sin"));
    
    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == sin(1.0f));
}

@("VM: ADD")
unittest {
    InExprBytecodeBuilder builder = nogc_new!InExprBytecodeBuilder();
    builder.buildADD();
    builder.buildRET(1);

    // Instantiate VM
    InExprVM vm = new InExprVM();
    vm.setGlobal(nstring("add"), InExprValue(builder.finalize()));

    vm.push(32.0);
    vm.push(32.0);
    int retValCount = vm.call(nstring("add"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 64.0f);
}

@("VM: SUB")
unittest {
    InExprBytecodeBuilder builder = nogc_new!InExprBytecodeBuilder();
    builder.buildSUB();
    builder.buildRET(1);

    // Instantiate VM
    InExprVM vm = new InExprVM();
    vm.setGlobal(nstring("sub"), InExprValue(builder.finalize()));

    vm.push(32.0);
    vm.push(32.0);
    int retValCount = vm.call(nstring("sub"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 0.0f);
}

@("VM: DIV")
unittest {
    InExprBytecodeBuilder builder = nogc_new!InExprBytecodeBuilder();
    builder.buildDIV();
    builder.buildRET(1);

    // Instantiate VM
    InExprVM vm = new InExprVM();
    vm.setGlobal(nstring("div"), InExprValue(builder.finalize()));

    vm.push(32.0);
    vm.push(2.0);
    int retValCount = vm.call(nstring("div"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 16.0f);
}

@("VM: MUL")
unittest {
    InExprBytecodeBuilder builder = nogc_new!InExprBytecodeBuilder();
    builder.buildMUL();
    builder.buildRET(1);

    // Instantiate VM
    InExprVM vm = new InExprVM();
    vm.setGlobal(nstring("mul"), InExprValue(builder.finalize()));

    vm.push(32.0);
    vm.push(2.0);
    int retValCount = vm.call(nstring("mul"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 64.0f);
}

@("VM: MOD")
unittest {
    InExprBytecodeBuilder builder = nogc_new!InExprBytecodeBuilder();
    builder.buildMOD();
    builder.buildRET(1);

    // Instantiate VM
    InExprVM vm = new InExprVM();
    vm.setGlobal(nstring("mod"), InExprValue(builder.finalize()));

    vm.push(32.0);
    vm.push(16.0);
    int retValCount = vm.call(nstring("mod"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 0.0f);
}

@("VM: JSR NATIVE")
unittest {
    import std.stdio : writeln;
    import inmath.math : sin;

    // Sin function
    static int mySinFunc(ref InExprStack stack) @nogc {
        InExprValue* v = stack.pop();
        if (v && v.isNumeric) {
            stack.push(sin(v.number));
            return 1;
        }
        return 0;
    }
    InExprBytecodeBuilder builder = nogc_new!InExprBytecodeBuilder();
    
    // Parameters
    builder.buildPUSH(1.0);
    
    // Function get
    builder.buildPUSH("sin");
    builder.buildGETG();

    // Jump
    builder.buildJSR(1);
    builder.buildRET(1);

    // Instantiate VM
    InExprVM vm = new InExprVM();
    vm.setGlobal(nstring("sin"), InExprValue(&mySinFunc));
    vm.setGlobal(nstring("bcfunc"), InExprValue(builder.finalize()));

    int retValCount = vm.call(nstring("bcfunc"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == sin(1.0f));
}