/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.io.inp.ctx;
import inochi2d.core.io.inp.node;
import numem.all;

/**
    Context for serialization and deserialization
*/
class InpContext {
@nogc:
private:
    set!(nstring) flags;


public:
    ~this() {
        nogc_delete(flags);
    }

    this() {
        
    }
    
    /**
        Gets whether a flag is set
    */
    final
    @safe
    bool hasFlag(nstring flag) {
        return flags.contains(flag);
    }

    /**
        Sets a flag
    */
    final
    @safe
    void setFlag(nstring flag, bool on=true) {
        if (on && !flags.contains(flag)) {
            flags.insert(flag);
        } else if (!on && flags.contains(flag)) {
            flags.remove(flag);
        }
    }

    /**
        Gets an iterator over the flags
    */
    final
    @trusted
    auto getFlags() {
        return flags.byKey();
    }
}