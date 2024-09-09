module inochi2d.expr.vm.builder;
import inochi2d.expr.vm.opcodes;
import inochi2d.expr.vm.stack;
import numem.all;

/**
    A builder which can emit InExpr instructions.
*/
final
class InExprBytecodeBuilder {
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
        if (eStackPtr >= IN_EXPR_STACK_SIZE) overflow = true;
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
        bytecode ~= InExprOpCode.NOP;
    }

    /**
        Builds a ADD instruction
    */
    void buildADD() {
        bytecode ~= InExprOpCode.ADD;
        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a SUB instruction
    */
    void buildSUB() {
        bytecode ~= InExprOpCode.SUB;
        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a DIV instruction
    */
    void buildDIV() {
        bytecode ~= InExprOpCode.DIV;
        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a MUL instruction
    */
    void buildMUL() {
        bytecode ~= InExprOpCode.MUL;
        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a MUL instruction
    */
    void buildMOD() {
        bytecode ~= InExprOpCode.MOD;
        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a NOT instruction
    */
    void buildNOT() {
        bytecode ~= InExprOpCode.NOT;
    }

    /**
        Builds a PUSH instruction
    */
    void buildPUSH(float immediate) {
        bytecode ~= InExprOpCode.PUSH_n;
        bytecode ~= toEndian(immediate, Endianess.littleEndian);
        eStackPtr++;
        this.validateStack();
    }

    /**
        Builds a PUSH instruction
    */
    void buildPUSH(nstring str) {
        bytecode ~= InExprOpCode.PUSH_s;
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
        bytecode ~= InExprOpCode.POP;
        bytecode ~= cast(ubyte)offset;
        bytecode ~= cast(ubyte)count;

        eStackPtr -= count;
        this.validateStack();
    }

    /**
        Builds a PEEK instruction
    */
    void buildPEEK(uint offset) {
        bytecode ~= InExprOpCode.PEEK;
        bytecode ~= cast(ubyte)offset;

        eStackPtr++;
        this.validateStack();
    }

    /**
        Builds a CMP instruction
    */
    void buildCMP(uint offsetA, uint offsetB) {
        bytecode ~= InExprOpCode.CMP;
        bytecode ~= cast(ubyte)offsetA;
        bytecode ~= cast(ubyte)offsetB;

        eStackPtr++;
        this.validateStack();
    }

    /**
        Builds a JMP instruction
    */
    void buildJMP(size_t offset) {
        bytecode ~= InExprOpCode.JMP;
        bytecode ~= toEndian(offset, Endianess.littleEndian);
    }

    /**
        Builds a JEQ instruction
    */
    void buildJEQ(size_t offset) {
        bytecode ~= InExprOpCode.JEQ;
        bytecode ~= toEndian(offset, Endianess.littleEndian);

        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a JEQ instruction
    */
    void buildJNQ(size_t offset) {
        bytecode ~= InExprOpCode.JEQ;
        bytecode ~= toEndian(offset, Endianess.littleEndian);

        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a JL instruction
    */
    void buildJL(size_t offset) {
        bytecode ~= InExprOpCode.JL;
        bytecode ~= toEndian(offset, Endianess.littleEndian);

        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a JG instruction
    */
    void buildJG(size_t offset) {
        bytecode ~= InExprOpCode.JG;
        bytecode ~= toEndian(offset, Endianess.littleEndian);

        eStackPtr--;
        this.validateStack();
    }

    /**
        Builds a JSR instruction
    */
    void buildJSR(size_t params) {
        bytecode ~= InExprOpCode.JSR;
        bytecode ~= cast(ubyte)params;

        eStackPtr++;
        this.validateStack();
    }

    /**
        Builds a RET instruction
    */
    void buildRET(size_t params) {
        bytecode ~= InExprOpCode.RET;
        bytecode ~= cast(ubyte)params;

        eStackPtr++;
        this.validateStack();
    }

    /**
        Builds a SETG instruction
    */
    void buildSETG() {
        bytecode ~= InExprOpCode.SETG;
        
        eStackPtr -= 2;
        this.validateStack();
    }

    /**
        Builds a GETG instruction
    */
    void buildGETG() {
        bytecode ~= InExprOpCode.GETG;
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