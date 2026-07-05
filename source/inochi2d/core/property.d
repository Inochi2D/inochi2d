/**
    Inochi2D Properties

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.property;
import numem.core.traits;
import numem.core.meta;
import nulib.quark;
import nulib;
import numem;

/**
    A type which contains properties.

    The public property interface interprets everything as floating point values.
*/
interface IPropertyOwner {
@nogc nothrow:

    /**
        Gets whether a property with the given name exists
        in the object.

        Params:
            key = The name of the property.
        
        Returns:
            $(D true) if the property exists,
            $(D false) otherwise.
    */
    bool hasProperty(quark key) const;

    /**
        Gets the value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The floating point value of the property.
    */
    float getProperty(quark key) const;

    /**
        Gets the default value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The default value of the property.
    */
    float getPropertyDefault(quark key) const;

    /**
        Sets the value of the property.

        Params:
            key =   The name of the property.
            value = The value to set the property to.
    */
    void setProperty(quark key, float value);

    /**
        Resets the given property.

        Params:
            key = The name of the property.
    */
    void resetProperty(quark key);

    /**
        Resets all properties.
    */
    void resetProperties();
}

/**
    The name of a property quark to initialize it to.
*/
struct propkey {
    string key;
}

/**
    Registers all quarks within the current module on library
    initialization.
*/
mixin template RegisterQuarks() {
    alias module_ = mixin(__MODULE__);
    enum modname = __traits(identifier, module_);

    pragma(crt_constructor)
    pragma(mangle, "__in_" ~ modname ~ "_quark_init")
    export extern (C) void __register_quarks() {
        import numem.core.traits : getUDAs, hasUDA;

        static foreach (member; __traits(allMembers, module_)) {
            static if (is(typeof(__traits(getMember, module_, member)) == immutable(quark))) {
                {
                    alias __member = __traits(getMember, module_, member);
                    static if (hasUDA!(__member, propkey)) {
                        enum KEY = getUDAs!(__member, propkey)[0].key;

                        pragma(msg, "Registering property ", KEY, " for ", member, "...");
                        __member = nu_quarkof(KEY);
                    } else {
                        pragma(msg, "Warning: ", member, " does not have a property name set, ignoring...");
                    }
                }
            }
        }
    }
}

/**
    A memory manager for properties.

    Properties can be of any type.
*/
struct PropertyStore {
private:
@nogc nothrow:
    HashTable!(quark, PropInfo) lut_;
    vector!quark keys_;
    size_t length_;
    void* vbuffer_;
    void* dbuffer_;

    static struct PropInfo {
        size_t offset;
        size_t size;
    }

    // Grows the property store's buffers by a given amount
    // of bytes, rounded up to 32-bits.
    size_t grow(size_t by) {
        size_t start = length_;
        this.length_ += nu_alignup(by - 1, 4);
        this.vbuffer_ = nu_realloc(vbuffer_, length_);
        this.dbuffer_ = nu_realloc(dbuffer_, length_);
        return start;
    }

public:

    /**
        All of the stored properties, untyped.
    */
    @property void[] properties() => vbuffer_[0 .. length_];

    /**
        The keys the store knows about.
    */
    @property quark[] keys() => keys_[];

    /**
        Size of the store, in bytes.
    */
    @property size_t size() nothrow pure => length_;

    /// Destructor
    ~this() {
        lut_.clear();
        keys_.clear();
        nu_free(vbuffer_);
        nu_free(dbuffer_);
    }

    /**
        Defines a property in the store.
    
        Params:
            key =       The key of the property.
            default_ =  The default value for the property.

        Returns:
            The index assigned to the definition.
    */
    size_t define(T)(quark key, T default_) {

        // If we already have a defintion, use that.
        if (auto i = key in lut_) {
            return i.offset;
        }

        // Otherwise make a new one.
        size_t offset = this.grow(T.sizeof);
        lut_[key] = PropInfo(offset, T.sizeof);
        keys_ ~= key;

        // Set default value and copy it to the set value.
        nu_memcpy(&dbuffer_[offset], cast(void*)&default_, T.sizeof);
        return offset;
    }

    /**
        Defines an overlay for a quark at the given memory location.

        Params:
            key =       The key to assign
            offset =    The offset to assign it at.

        Returns:
            The offset that the overlay was created at,
            $(D -1) if the overlay could not be created.
    */
    ptrdiff_t defineOverlay(T)(quark key, size_t offset) {

        // If we already have a defintion, use that.
        if (auto i = key in lut_) {
            return i.offset;
        }

        // Make sure we're in range.
        if (offset + T.sizeof <= this.length_) {
            lut_[key] = PropInfo(offset, T.sizeof);
            keys_ ~= key;
            return offset;
        }
        return -1;
    }

    /**
        Gets the offset of the given quark in the
        property store.

        Params:
            q = The quark to look up.
    
        Returns:
            The index of $(D q) in $(D properties) if found,
            $(D -1) otherwise.
    */
    ptrdiff_t offsetOf(quark q) inout {
        if (auto i = q in lut_)
            return i.offset;
        return -1;
    }

    /**
        Gets the given value from the given offset.

        Params:
            offset = The offset of the value to get.

        Returns:
            The value at that given offset if found,
            $(D T.init) otherwise.
    */
    T getFromIndex(T)(size_t offset) inout {
        if (offset + T.sizeof > this.length_)
            return T.init;

        return *(cast(T*)(vbuffer_ + offset));
    }

    /**
        Gets a property from its quark.

        Params:
            q = The property quark.

        Returns:
            The value for the given quark if found,
            $(D initial) otherwise.
    */
    T get(T)(quark q) inout {
        if (auto i = q in lut_) {
            assert(i.size == T.sizeof, "Tried to get property type of mismatching size.");
            if (i.size != T.sizeof)
                return T.init;

            return (*cast(T*)(&vbuffer_[i.offset]));
        }
        return T.init;
    }

    /**
        Gets the default value of a property from its quark.

        Params:
            q = The property quark.

        Returns:
            The default value of the property if found,
            $(D initial) otherwise.
    */
    T getDefault(T)(quark q) inout {
        if (auto i = q in lut_) {
            assert(i.size == T.sizeof, "Tried to get property type of mismatching size.");
            if (i.size != T.sizeof)
                return T.init;

            return (*cast(T*)(&dbuffer_[i.offset]));
        }
        return T.init;
    }

    /**
        Sets a property from its quark.

        Params:
            q =     The property quark.
            value = The value to set.
    */
    void set(T)(quark q, T value) {
        if (auto i = q in lut_) {
            assert(i.size == T.sizeof, "Tried to set mismatched size data for property.");
            if (i.size != T.sizeof)
                return;

            (*cast(T*)(&vbuffer_[i.offset])) = value;
        }
    }

    /**
        Sets a property to its default value.

        Params:
            q =     The property quark.
    */
    void reset(quark q) {
        if (auto i = q in lut_)
            nu_memcpy(&vbuffer_[i.offset], &dbuffer_[i.offset], i.size);
    }

    /**
        Resets all of the properties of the store.
    */
    void resetAll() {
        nu_memcpy(vbuffer_, dbuffer_, length_);
    }
}

/**
    A type which contains a value and an offset for said value.
*/
struct offset_value(T, string offsetOp = "+") { // @suppress(dscanner.style.phobos_naming_convention)
public:
@nogc:
    alias value this;
    T base;
    T offset;

    /**
        The combined value.
    */
    @property T value() => mixin("base ", offsetOp, " offset");
}
