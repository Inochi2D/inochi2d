module inochi2d.core.io.serializer;
import numem.all;

/**
    The base class for serializers which can serialize Inochi2D Puppets
*/
abstract
class InIOSerializerContext {
@nogc:
private:
    set!(nstring) flags;

public:
    
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

/**
    Base class for all tree traversal
*/
abstract
class InIOTreeContext {
@nogc:
    abstract void enter(nstring name);
}