/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.expr.compiler.builder;
import inochi2d.core.expr.vm.opcodes;
import inochi2d.core.expr.vm.stack;
import numem.all;

/**
    A builder which can emit Inochi2D Expression instructions.
*/
final
class InVmBytecodeBuilder {
@nogc:
private:
    vector!ubyte bytecode;

    map!(nstring, size_t) labels;

    ptrdiff_t eStackPtr;
    bool underflow;
    bool overflow;

    // Validates the code every stack step.
    void validateStack() {
        if (eStackPtr < 0) underflow = true;
        if (eStackPtr >= INVM_STACK_SIZE) overflow = true;
    }

public:
    ~this() {
        nogc_delete(labels);
    }

    this() {
        this.eStackPtr = 0;
    }

    /**
        Adds a label at the current instruction
    */
    void setLabel(nstring label) {
        labels[label] = bytecode.size()-1;
    }

    /**
        Adds a label at the current instruction
    */
    void setLabel(string label) {
        this.setLabel(nstring(label));
    }

    /**
        Gets the bytecode position of a label
    */
    ptrdiff_t getLabel(nstring label) {
        if (label in labels) {
            return labels[label];
        }
        
        return -1;
    }

    /**
        Gets the bytecode position of a label
    */
    ptrdiff_t getLabel(string label) {
        return this.getLabel(nstring(label));
    }

    /**
        Builds a NOP instruction
    */
    void buildNOP() {
        bytecode ~= InVmOpCode.NOP;
    }

    /**
        Builds a ADD instruction
    */
    void buildADD() {
        bytecode ~= InVmOpCode.ADD;
        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a SUB instruction
    */
    void buildSUB() {
        bytecode ~= InVmOpCode.SUB;
        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a DIV instruction
    */
    void buildDIV() {
        bytecode ~= InVmOpCode.DIV;
        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a MUL instruction
    */
    void buildMUL() {
        bytecode ~= InVmOpCode.MUL;
        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a MUL instruction
    */
    void buildMOD() {
        bytecode ~= InVmOpCode.MOD;
        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a NEG instruction
    */
    void buildNEG() {
        bytecode ~= InVmOpCode.NEG;
    }

    /**
        Builds a PUSH instruction
    */
    void buildPUSH(float immediate) {
        bytecode ~= InVmOpCode.PUSH_n;
        bytecode ~= toEndian(immediate, Endianess.littleEndian);
        eStackPtr++;
        this.validateStack();
    }

    /**
        Builds a PUSH instruction
    */
    void buildPUSH(string str) {
        this.buildPUSH(nstring(str));
    }

    /**
        Builds a PUSH instruction
    */
    void buildPUSH(nstring str) {
        bytecode ~= InVmOpCode.PUSH_s;
        bytecode ~= toEndian(cast(uint)str.length(), Endianess.littleEndian);
        bytecode ~= cast(ubyte[])str[0..$];
        eStackPtr++;
        this.validateStack();
    }

    /**
        Builds a POP instruction
    */
    void buildPOP(uint count) {
        this.buildPOP(0, count);
    }

    /**
        Builds a POP instruction
    */
    void buildPOP(uint offset, uint count) {
        bytecode ~= InVmOpCode.POP;
        bytecode ~= cast(ubyte)offset;
        bytecode ~= cast(ubyte)count;

        eStackPtr -= count;
        this.validateStack();
    }

    /**
        Builds a PEEK instruction
    */
    void buildPEEK(uint offset) {
        bytecode ~= InVmOpCode.PEEK;
        bytecode ~= cast(ubyte)offset;

        eStackPtr++;
        this.validateStack();
    }

    /**
        Builds a CMP instruction
    */
    void buildCMP(uint offsetA, uint offsetB) {
        bytecode ~= InVmOpCode.CMP;
        bytecode ~= cast(ubyte)offsetA;
        bytecode ~= cast(ubyte)offsetB;

        eStackPtr++;
        this.validateStack();
    }

    /**
        Builds a JMP instruction
    */
    void buildJMP(size_t offset) {
        bytecode ~= InVmOpCode.JMP;
        bytecode ~= toEndian(offset, Endianess.littleEndian);
    }

    /**
        Builds a JEQ instruction
    */
    void buildJEQ(size_t offset) {
        bytecode ~= InVmOpCode.JEQ;
        bytecode ~= toEndian(offset, Endianess.littleEndian);

        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a JEQ instruction
    */
    void buildJNQ(size_t offset) {
        bytecode ~= InVmOpCode.JEQ;
        bytecode ~= toEndian(offset, Endianess.littleEndian);

        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a JL instruction
    */
    void buildJL(size_t offset) {
        bytecode ~= InVmOpCode.JL;
        bytecode ~= toEndian(offset, Endianess.littleEndian);

        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a JG instruction
    */
    void buildJG(size_t offset) {
        bytecode ~= InVmOpCode.JG;
        bytecode ~= toEndian(offset, Endianess.littleEndian);

        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a JSR instruction
    */
    void buildJSR() {
        bytecode ~= InVmOpCode.JSR;
    }

    /**
        Builds a RET instruction
    */
    void buildRET() {
        bytecode ~= InVmOpCode.RET;
    }

    /**
        Builds a SETG instruction
    */
    void buildSETG() {
        bytecode ~= InVmOpCode.SETG;
        
        eStackPtr -= 2;
        this.validateStack();
    }

    /**
        Builds a GETG instruction
    */
    void buildGETG() {
        bytecode ~= InVmOpCode.GETG;
    }

    /**
        Whether code underflows stack
    */
    bool hasUnderflow() {
        return underflow;
    }
    
    /**
        Whether code overflows stack
    */
    bool hasOverflow() {
        return overflow;
    }

    /**
        Finalizes the bytecode
    */
    vector!ubyte finalize() {
        
        // Padding NOP needed.
        this.buildNOP();
        vector!ubyte finalized = vector!ubyte(bytecode);

        bytecode.resize(0);
        eStackPtr = 0;
        underflow = false;
        overflow = false;

        return finalized;
    }
}