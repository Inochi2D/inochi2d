/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/
module inochi2d.core.expr.vm.stack;
import inochi2d.core.expr.vm.value;
import numem.all;

/**
    Size of a VM stack.
*/
enum INVM_STACK_SIZE = 64;

/**
    A stack-frame, normally not user accessible.
*/
struct InVmFrame {

    /**
        Whether the frame is within the VM.
    */
    bool isWithinVM;

    /**
        Program
    */
    ubyte[] prog;

    /**
        Program Counter
    */
    uint pc;
}

/**
    A VM stack
*/
final
class InVmStack(T) {
@nogc:
private:
    size_t sp = 0;
    T[INVM_STACK_SIZE] stack;

public:

    ~this() {
        foreach(i; 0..INVM_STACK_SIZE) {
            nogc_delete(stack[i]);
        }
    }

    /**
        Pushes an item to the stack
    */
    void push(T item) {
        if (sp+1 >= INVM_STACK_SIZE) return;
        stack[sp++] = item;
    }

    /**
        Inserts value at offset.
    */
    void insert(T val, ptrdiff_t offset) {
        ptrdiff_t rsp = cast(ptrdiff_t)sp;
        if (rsp+1 >= INVM_STACK_SIZE) return;
        
        // Insert end
        if (offset == 0) {
            this.push(val);
            return;
        }

        // Snap to bottom
        if (rsp - offset <= 0) {
            stack[1..sp+1] = stack[0..sp];
            stack[0] = val;
            sp++;
            return;
        }

        // Insert middle
        ptrdiff_t start = rsp-offset;
        stack[start+1..rsp+1] = stack[start..rsp];
        stack[start] = val;
    }

    /**
        Pops a range of values off the stack
    */
    void pop(ptrdiff_t offset, ptrdiff_t count) {
        ptrdiff_t rsp = cast(ptrdiff_t)sp;

        if (offset == 0) {
            this.pop(count);
        } else if (offset > 0) {

            ptrdiff_t start = rsp-offset;
            ptrdiff_t end = start-count;

            ptrdiff_t toCopy = rsp-start;

            if (end < 0) return;
            if (start > rsp) return;
            if (toCopy > 0) {

                // Be good citizens and do some housekeeping.
                foreach(i; end..end+toCopy) {
                    nogc_delete(stack[i]);
                }

                stack[end..end+toCopy] = stack[start..start+toCopy];
                sp -= count;
            }
        }
    }

    /**
        Pops a range of values off the stack
    */
    void pop(ptrdiff_t count) {
        ptrdiff_t rsp = cast(ptrdiff_t)sp;
        if (rsp-count < 0) return;
        sp -= count;
    }

    /**
        Pops the top value off the stack
    */
    T* pop() {
        ptrdiff_t rsp = cast(ptrdiff_t)sp;
        if (rsp-1 < 0) return null;
        return &stack[--sp];
    }


    /**
        Gets the value at a specific offset.
        Returns null if peeking below 0 or above the stack pointer.
    */
    T* peek(ptrdiff_t offset) {
        ptrdiff_t rsp = cast(ptrdiff_t)sp-1;
        
        if (rsp-offset < 0) return null;
        if (rsp-offset > rsp) return null;

        return &stack[rsp-offset];
    }

    /**
        Gets the stack depth
    */
    size_t getDepth() {
        return sp;
    }

    /**
        Gets the maximum depth of the stack
    */
    size_t getMaxDepth() {
        return INVM_STACK_SIZE;
    }
}

alias InVmValueStack = InVmStack!InVmValue;
alias InVmCallStack = InVmStack!InVmFrame;