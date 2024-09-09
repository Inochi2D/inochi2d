/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/
module inochi2d.expr.vm.stack;
import inochi2d.expr.vm.value;
import numem.all;

/**
    Size of a VM stack.
*/
enum IN_EXPR_STACK_SIZE = 64;

/**
    The execution stack of a VM

    TODO: Add stack overflow and underflow exceptions.
*/
final
class InExprStack {
@nogc:
private:

    size_t sp = 0;
    InExprValue[IN_EXPR_STACK_SIZE] stack;

public:

    ~this() {
        foreach(i; 0..IN_EXPR_STACK_SIZE) {
            nogc_delete(stack[i]);
        }
    }

    /**
        Pushes a float to the stack
    */
    void push(float f32) {
        if (sp+1 >= IN_EXPR_STACK_SIZE) return;
        stack[sp++] = InExprValue(f32);
    }

    /**
        Pushes a string slice to the stack
    */
    void push(string str) {
        if (sp+1 >= IN_EXPR_STACK_SIZE) return;
        stack[sp++] = InExprValue(nstring(str));
    }

    /**
        Pushes a string to the stack
    */
    void push(nstring str) {
        if (sp+1 >= IN_EXPR_STACK_SIZE) return;
        stack[sp++] = InExprValue(str);
    }
    
    /**
        Pushes a ExprValue to the stack
    */
    void push(InExprValue val) {
        if (sp+1 >= IN_EXPR_STACK_SIZE) return;
        stack[sp++] = val;
    }

    /**
        Inserts value at offset.
    */
    void insert(InExprValue val, ptrdiff_t offset) {
        ptrdiff_t rsp = cast(ptrdiff_t)sp;
        if (rsp+1 >= IN_EXPR_STACK_SIZE) return;
        
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
    InExprValue* pop() {
        ptrdiff_t rsp = cast(ptrdiff_t)sp;
        if (rsp-1 < 0) return null;
        return &stack[--sp];
    }


    /**
        Gets the value at a specific offset.
        Returns null if peeking below 0 or above the stack pointer.
    */
    InExprValue* peek(ptrdiff_t offset) {
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
        return IN_EXPR_STACK_SIZE;
    }

    /**
        Dumps stack to stdout
    */
    void dumpStack() {
        import core.stdc.stdio : printf;
        foreach_reverse(i; 0..sp) {
            final switch(stack[i].getType()) {
                case InExprValueType.NONE:
                    printf("%d: null (none)\n", cast(int)i);
                    return;
                case InExprValueType.number:
                    printf("%d: %f (number)\n", cast(int)i, stack[i].number);
                    return;
                case InExprValueType.str:
                    printf("%d: %s (string)\n", cast(int)i, stack[i].str.toCString());
                    return;
                case InExprValueType.returnAddr:
                    printf("%d: %d (return addr)\n", cast(int)i, stack[i].retptr.pc);
                    return;
                case InExprValueType.nativeFunction:
                    printf("%d: %p (return addr)\n", cast(int)i, cast(void*)stack[i].func);
                    return;
                case InExprValueType.bytecode:
                    printf("%d: (bytecode, %u bytes)\n", cast(int)i, cast(uint)stack[i].bytecode.size());
                    return;
                
            }
        }
    }
}