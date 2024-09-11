/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

/**
    Inochi2D Expression Virtual Machine

    This is a small virtual machine (programming language) for executing
    mathematical expressions within the context of Inochi2D.

    The VM seperates call and value stacks and strictly limits which
    types may be used in conjunction with it for security.

    The VM is stack based and uses not JIT, for maximum compatibility
    with platforms which do not support the use of JIT compilation.
*/
module inochi2d.expr.vm;

public import inochi2d.expr.vm.vm;
public import inochi2d.expr.vm.value;
public import inochi2d.expr.vm.stack;