/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

module inochi2d.core.io.tree.ctx;
import inochi2d.core.io.tree.value;
import numem.core.uuid;
import numem.all;
import inochi2d.puppet.node;

/**
    Context for serialization and deserialization
*/
class InDataContext {
@nogc:
private:
    set!(nstring) flags;
    map!(uint, UUID) mappings;
    InTreeValue root;


public:
    ~this() {
        nogc_delete(flags);
    }

    this() {
        root = InTreeValue.newObject();
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
        Maps a legacy id to a UUID
    */
    UUID mapLegacyID(uint id) {
        mappings[id] = inNewUUID();
        return mappings[id];
    }

    /**
        Gets the UUID the legacy ID maps to
    */
    UUID getMappingFor(uint id) {
        if (id in mappings) return mappings[id];
        return UUID.nil;
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

    /**
        Gets the root of the serialization context
    */
    final
    ref InTreeValue getRoot() {
        return root;
    }
}