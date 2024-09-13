/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.expr.vm.opcodes;
import numem.all;

enum InVmOpCode : ubyte {

    /// No-op, placeholder opcode.
    NOP = 0x00,

    //
    //      MATH OPCODES
    //

    /// Add top 2 values of stack
    ADD = 0x01,

    /// Subtract top 2 values of stack
    SUB = 0x02,

    /// Divide top 2 values of stack
    DIV = 0x03,

    /// Multiply top 2 values of stack
    MUL = 0x04,

    /// Modulo top 2 values of stack
    MOD = 0x05,

    /// Negate value
    NEG = 0x06,

    

    //
    //      STACK OPCODES
    //

    // Push number to stack
    PUSH_n = 0x10,

    // Push string to stack
    PUSH_s = 0x13,

    /// Pop value range off stack
    POP = 0x1A,

    /// Peek value on stack
    PEEK = 0x1B,


    //
    //      JUMP OPCODES
    //

    /// Compare top 2 values of stack
    CMP = 0x20,

    /// Unconditional jump
    JMP = 0x21,

    /// Jump if equal
    JEQ = 0x22,

    /// Jump if equal
    JNQ = 0x23,

    /// Jump if less-than
    JL  = 0x24,

    /// Jump if less-than or equal
    JLE = 0x25,

    /// Jump if greater-than
    JG  = 0x26,

    /// Jump if greater-than or equal
    JGE  = 0x27,

    /// Jump to subroutine
    JSR = 0x28,

    /// Return from subroutine
    RET = 0x29,

    //
    //      HEAP OPCODES
    //

    /// Set global
    SETG = 0x30,

    /// Get global
    GETG = 0x31,
}