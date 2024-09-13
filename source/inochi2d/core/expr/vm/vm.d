/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.expr.vm.vm;
import inochi2d.core.expr.vm.value;
import inochi2d.core.expr.vm.opcodes;
import inochi2d.core.expr.vm.stack;
import numem.all;
import std.string;

private {
    
    // Vm execution state
    struct _vmExecutionState {
    @nogc:

        // Value Stack
        InVmValueStack stack;

        // Call stack
        InVmCallStack callStack;

        /// Bytecode being executed
        ubyte[] bc;

        /// Program counter
        uint pc;

        /// Current operation flag
        ubyte flags;

        /// Get if the previous CMP flag was set to Equal
        bool flagEq() {
            return (flags & InVmFlag.eq) != 0;
        }

        /// Get if the previous CMP flag was set to Below
        bool flagBelow() {
            return (flags & InVmFlag.below) != 0;
        }

        /// Get if the previous CMP flag was set to Above
        bool flagAbove() {
            return flags == 0;
        }
    }

    // Vm execution state flags
    enum InVmFlag : ubyte {
        /// Equal flag (zero flag)
        eq          = 0b0000_0001,

        /// Below flag (carry flag)
        below       = 0b0000_0010,

        /// Invalid operation flag.
        invalidOp   = 0b0001_0000,
    }

    // An itme in the global store
    struct _vmGlobalItem {
        bool writeProtected;
        InVmValue value;
    }
}

/**
    A execution environment
*/
abstract
class InVmState {
@nogc:
private:
    _vmExecutionState state;

    void _vmcmp(T)(T lhs, T rhs) {
        state.flags = 0;

        if (lhs == rhs) state.flags |= InVmFlag.eq;
        if (lhs < rhs)  state.flags |= InVmFlag.below;
    }

    struct _vmGlobalState {
    @nogc:
        map!(nstring, _vmGlobalItem) globals;

        bool set(bool host=false)(nstring name, InVmValue value, bool writeProtect=false) {

            // Handle write protection.
            static if (!host) {
                if (name in globals) {
                    if (globals[name].writeProtected) 
                        return false;
                }
            }

            globals[name] = _vmGlobalItem(
                host && writeProtect,
                value
            );

            return true;
        }

        InVmValue* get(nstring name) {
            if (name in globals) {
                return &globals[name].value;
            }
            return null;
        }
    }

    bool _vcall(InVmValue* func) {

        // Get information
        if (!func || !func.isCallable()) return false;

        // Store stack frame
        InVmFrame frame;
        if (state.callStack.getDepth() == 0) {
            frame.isWithinVM = false;
        } else {
            frame.isWithinVM = true;
            frame.prog = state.bc;
            frame.pc = state.pc;
        }
        state.callStack.push(frame);

        // Call function.
        if (func.isNativeFunction()) {
            func.func(this);

        } else {

            this.state.pc = 0;
            this.state.bc = func.bytecode[];
        }

        return true;
    }

    bool _vreturn() {
        ptrdiff_t stackDepth = cast(ptrdiff_t)state.callStack.getDepth();
        
        // Return to caller
        InVmFrame* frame = state.callStack.pop();

        // No frame?
        if (!frame) return false;

        // NOTE: Native functions may end up calling back into the VM.
        // This value should be set by JSR when calling into a native function.
        // which tells it to return to caller.
        if (!frame.isWithinVM) return false;

        // Restore previous frame
        this.state.pc = frame.pc;
        this.state.bc = frame.prog;
        return true;
    }

protected:

    /**
        Gets the local execution state
    */
    final
    _vmExecutionState getState() {
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
        InVmOpCode opcode = cast(InVmOpCode)state.bc[state.pc++];
        
        switch(opcode) {
            default:
                return false;

            case InVmOpCode.NOP:
                return true;
            
            case InVmOpCode.ADD:
                InVmValue* rhsp = state.stack.peek(0);
                InVmValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InVmValue rhs = *rhsp;
                InVmValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    state.stack.pop(2);
                    state.stack.push(InVmValue(lhs.number + rhs.number));
                }
                return false;
            
            case InVmOpCode.SUB:
                InVmValue* rhsp = state.stack.peek(0);
                InVmValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InVmValue rhs = *rhsp;
                InVmValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    state.stack.pop(2);
                    state.stack.push(InVmValue(lhs.number - rhs.number));
                }
                return false;
            
            case InVmOpCode.MUL:
                InVmValue* rhsp = state.stack.peek(0);
                InVmValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InVmValue rhs = *rhsp;
                InVmValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    state.stack.pop(2);
                    state.stack.push(InVmValue(lhs.number * rhs.number));
                }
                return false;
            
            case InVmOpCode.DIV:
                InVmValue* rhsp = state.stack.peek(0);
                InVmValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InVmValue rhs = *rhsp;
                InVmValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    state.stack.pop(2);
                    state.stack.push(InVmValue(lhs.number / rhs.number));
                }
                return false;
            
            case InVmOpCode.MOD:
                InVmValue* rhsp = state.stack.peek(0);
                InVmValue* lhsp = state.stack.peek(1);
                if (!rhsp || !lhsp) 
                    return false;

                InVmValue rhs = *rhsp;
                InVmValue lhs = *lhsp;

                if (lhs.isNumeric && rhs.isNumeric) {
                    import inmath.math : fmodf;
                    state.stack.pop(2);
                    state.stack.push(InVmValue(fmodf(lhs.number, rhs.number)));
                }
                return false;
            
            case InVmOpCode.NEG:
                InVmValue* lhsp = state.stack.peek(0);
                if (!lhsp) 
                    return false;
                
                InVmValue lhs = *lhsp;

                if (lhs.isNumeric) {
                    state.stack.pop(1);
                    state.stack.push(InVmValue(-lhs.number));
                }
                return false;

            case InVmOpCode.PUSH_n:
                ubyte[4] val = state.bc[state.pc..state.pc+4];
                float f32 = fromEndian!float(val, Endianess.littleEndian);
                state.stack.push(InVmValue(f32));
                state.pc += 4;
                return true;

            case InVmOpCode.PUSH_s:
                ubyte[4] val = state.bc[state.pc..state.pc+4];
                state.pc += 4;

                uint length = fromEndian!uint(val, Endianess.littleEndian);
                
                // Invalid string.
                if (state.pc+length >= state.bc.length)
                    return false;

                nstring nstr = cast(string)state.bc[state.pc..state.pc+length];
                state.stack.push(InVmValue(nstr));

                state.pc += length;
                return true;

            case InVmOpCode.POP:
                ptrdiff_t offset = state.bc[state.pc++];
                ptrdiff_t count = state.bc[state.pc++];
                state.stack.pop(offset, count);
                return true;

            case InVmOpCode.PEEK:
                ptrdiff_t offset = state.bc[state.pc++];
                state.stack.push(*state.stack.peek(offset));
                return true;

            case InVmOpCode.CMP:
                state.flags = InVmFlag.invalidOp;

                InVmValue* rhs = state.stack.peek(0);
                InVmValue* lhs = state.stack.peek(1);

                if (lhs.isNumeric && rhs.isNumeric) {
                    _vmcmp(lhs.number, rhs.number);
                }
                return false;

            case InVmOpCode.JMP:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                this.jump(addr);
                return true;

            case InVmOpCode.JEQ:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagEq())
                    this.jump(addr);
                return true;

            case InVmOpCode.JNQ:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (!state.flagEq())
                    this.jump(addr);
                return true;

            case InVmOpCode.JL:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagBelow())
                    this.jump(addr);
                return true;

            case InVmOpCode.JLE:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagBelow() || state.flagEq())
                    this.jump(addr);
                return true;

            case InVmOpCode.JG:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagAbove())
                    this.jump(addr);
                return true;

            case InVmOpCode.JGE:
                ubyte[4] var = state.bc[state.pc..state.pc+4];
                uint addr = fromEndian!uint(var, Endianess.littleEndian);
                state.pc += 4;

                if (state.flagAbove() || state.flagEq())
                    this.jump(addr);
                return true;

            case InVmOpCode.JSR:

                // Get information
                InVmValue* func = state.stack.pop();
                return this._vcall(func);

            case InVmOpCode.RET:
                return this._vreturn();

            case InVmOpCode.SETG:
                InVmValue* name = state.stack.pop();
                InVmValue* item = state.stack.pop();

                if (name && item && name.getType() == InVmValueType.str) {
                    state.stack.pop(2);
                    
                    // TODO: emit error if write protected.
                    return this.getGlobalState().set(name.str, *item);
                }
                return false;
                
            case InVmOpCode.GETG:
                InVmValue* name = state.stack.pop();
                if (name && name.getType() == InVmValueType.str) {

                    InVmValue* val = this.getGlobalState().get(name.str);
                    if (val) {
                        state.stack.push(*val);
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
    void run() {
        while(this.runOne()) { }
    }

    this() {
        state.stack = nogc_new!InVmValueStack();
        state.callStack = nogc_new!InVmCallStack();
    }

public:

    ~this() {
        nogc_delete(state.stack);
        nogc_delete(state.callStack);
    }

    /**
        Gets global value
    */
    InVmValue* getGlobal(nstring name) {
        return getGlobalState().get(name);
    }

    /**
        Sets global value
    */
    void setGlobal(nstring name, InVmValue value, bool writeProtect=false) {
        getGlobalState().set!true(name, value, writeProtect);
    }

    /**
        Pushes a float to the stack
    */
    final
    void push(float f32) {
        state.stack.push(InVmValue(f32));
    }

    /**
        Pushes a string to the stack
    */
    final
    void push(nstring str) {
        state.stack.push(InVmValue(str));
    }
    
    /**
        Pushes a value to the stack
    */
    final
    void push(InVmValue val) {
        state.stack.push(val);
    }

    /**
        Pops a value from the stack
    */
    final
    InVmValue* peek(ptrdiff_t offset) {
        return state.stack.peek(offset);
    }

    /**
        Pops a value from the stack
    */
    final
    InVmValue* pop() {
        return state.stack.pop();
    }

    /**
        Pops a range of values off the stack
    */
    final
    void pop(ptrdiff_t offset, size_t count) {
        state.stack.pop(offset, count);
    }

    /**
        Gets depth of stack
    */
    final
    size_t getStackDepth() {
        return state.stack.getDepth();
    }

    /**
        Executes code in global scope.

        Returns size of stack after operation.
        Returns -1 on error.
    */
    int execute(ubyte[] bytecode) {
        if (state.callStack.getDepth() == 0) {
            state.bc = bytecode;
            state.pc = 0;

            // Run and get return values
            this.run();

            // Reset code and program counter.
            state.pc = 0;
            state.bc = null;
            return cast(int)this.getStackDepth();
        }
        return -1;
    }

    /**
        Calls a global function

        Returns return value count.
        Returns -1 on error.
    */
    int call(nstring gfunc) {
        InVmValue* v = this.getGlobal(gfunc);
        if (v && v.isCallable()) {
            if (this._vcall(v) && v.isBytecodeBlob()) {
                this.run();
            }
            return cast(int)this.getStackDepth();
        }
        return -1;
    }
}

class InVmVM : InVmState {
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
}


//
//      UNIT TESTS
//

import inochi2d.core.expr.compiler.builder : InVmBytecodeBuilder;

@("VM: NATIVE CALL")
unittest {
    import inmath.math : sin;

    // Sin function
    static int mySinFunc(ref InVmState state) @nogc {
        InVmValue* v = state.pop();
        if (v && v.isNumeric) {
            state.push(sin(v.number));
            return 1;
        }
        return 0;
    }

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("sin"), InVmValue(&mySinFunc));

    vm.push(1.0);
    int retValCount = vm.call(nstring("sin"));
    import std.stdio : writeln;
    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == sin(1.0f));
}

@("VM: ADD")
unittest {
    InVmBytecodeBuilder builder = nogc_new!InVmBytecodeBuilder();
    builder.buildADD();
    builder.buildRET();

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("add"), InVmValue(builder.finalize()));

    vm.push(32.0);
    vm.push(32.0);
    int retValCount = vm.call(nstring("add"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 64.0f);
}

@("VM: SUB")
unittest {
    InVmBytecodeBuilder builder = nogc_new!InVmBytecodeBuilder();
    builder.buildSUB();
    builder.buildRET();

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("sub"), InVmValue(builder.finalize()));

    vm.push(32.0);
    vm.push(32.0);
    int retValCount = vm.call(nstring("sub"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 0.0f);
}

@("VM: DIV")
unittest {
    InVmBytecodeBuilder builder = nogc_new!InVmBytecodeBuilder();
    builder.buildDIV();
    builder.buildRET();

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("div"), InVmValue(builder.finalize()));

    vm.push(32.0);
    vm.push(2.0);
    int retValCount = vm.call(nstring("div"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 16.0f);
}

@("VM: MUL")
unittest {
    InVmBytecodeBuilder builder = nogc_new!InVmBytecodeBuilder();
    builder.buildMUL();
    builder.buildRET();

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("mul"), InVmValue(builder.finalize()));

    vm.push(32.0);
    vm.push(2.0);
    int retValCount = vm.call(nstring("mul"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == 64.0f);
}

@("VM: MOD")
unittest {
    InVmBytecodeBuilder builder = nogc_new!InVmBytecodeBuilder();
    builder.buildMOD();
    builder.buildRET();

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("mod"), InVmValue(builder.finalize()));

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
    static int mySinFunc(ref InVmState state) @nogc {
        InVmValue* v = state.pop();
        if (v && v.isNumeric) {
            state.push(sin(v.number));
            return 1;
        }
        return 0;
    }
    InVmBytecodeBuilder builder = nogc_new!InVmBytecodeBuilder();
    
    // Parameters
    builder.buildPUSH(1.0);
    
    // Function get
    builder.buildPUSH("sin");
    builder.buildGETG();

    // Jump
    builder.buildJSR();
    builder.buildRET();

    // Instantiate VM
    InVmVM vm = new InVmVM();
    vm.setGlobal(nstring("sin"), InVmValue(&mySinFunc));
    vm.setGlobal(nstring("bcfunc"), InVmValue(builder.finalize()));

    int retValCount = vm.call(nstring("bcfunc"));

    assert(retValCount == 1);
    assert(vm.getStackDepth() == retValCount);
    assert(vm.pop().number == sin(1.0f));
}