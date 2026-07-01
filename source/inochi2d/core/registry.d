/**
    Shared core subsystem for type registration and instantiation.

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.registry;
import numem.core.lifetime;
import numem.core.memory;
import numem.core.traits;
import inp.format;
import numem;
import nulib;

/**
    A UDA applied to types in Inochi2D to allow them to be instantiated
    using an object model. Types both may have a string and numeric ID.
*/
struct TypeId {
    string sid;
    uint nid;

    enum nil = TypeId(null, uint.max);
}

/**
    Creates a reserved Inochi2D ID tag.
*/
enum MAKE_I2D_TAG(ubyte subclass, ubyte superclass) =
    (cast(uint)subclass << 8) |
    (cast(uint)superclass);

/**
    Tells the registry only to register the TypeId,
    but not the factories for a type.
*/
struct TypeIdAbstract;

/**
    Tells the registry that the type should be used as a fallback
    if the type can't be resolved.
*/
struct RegisterFallback;

/**
    Template which registers a type into a given type registry.
*/
mixin template Register(T, alias registry) {
    import numem.core.traits : hasUDA;

    static if (hasUDA!(T, TypeId)) {
        pragma(msg, "Registering ", T.stringof, " in ", registry.stringof, "...");

        pragma(crt_constructor)
        pragma(mangle, "__in_register_"~T.stringof)
        export extern(C) void __register_type() { registry.register!T(); }
    }

    static if (hasUDA!(T, RegisterFallback)) {
        pragma(msg, "Registering ", T.stringof, " as fallback type in ", registry.stringof, "...");
    }
}

/**
    A type registry that stores mappings between name and numeric IDs
    and their classes.
*/
struct TypeRegistry(T, Args...) {
private:
    // dfmt off
    alias __TypeMap(Key, Value) = MapImpl!(Key, Value, (a, b) => a < b, false, false);
    static X __construct(X)(Args args) @nogc {
            return assumeNoGC((Args args) {
                return new(nu_mallocT!X()) X(args);
            }, 
            args
        );
    }
    // dfmt on

@nogc:
    alias factory_t = T function(Args);
    __TypeMap!(void*, TypeId) typeIdStore;
    __TypeMap!(string, factory_t) factoryStoreS;
    __TypeMap!(uint, factory_t) factoryStoreN;
    factory_t fallbackFactory;
    vector!size_t sizeStore;

public:

    /**
        Arguments
    */
    alias ArgsT = Args;

    /**
        The alignment needed to store registered objects in sequential memory.
    */
    @property size_t alignment() {
        size_t result = 0;
        foreach(sz; sizeStore)
            if (sz > result)
                result = sz;
            
        return result;
    }

    /**
        Registers the given type in the type registry.

        Params:
            X = The object to register.
    */
    void register(X)() {
        import numem.core.traits : getUDAs, hasUDA;
        static assert(hasUDA!(X, TypeId), X.stringof ~ " does not have a TypeId UDA!");

        alias _tids = getUDAs!(X, TypeId);
        typeIdStore[cast(void*)typeid(X)] = _tids[0];
        sizeStore ~= AllocSize!X;

        // Register type factory.
        static if (!hasUDA!(X, TypeIdAbstract)) {
            static foreach(tid; _tids) {
                factoryStoreS[tid.sid] = &__construct!X;
                factoryStoreN[tid.nid] = &__construct!X;
            }
        }

        // Register fallback factory.
        static if (hasUDA!(X, RegisterFallback)) {
            fallbackFactory = &__construct!X;
        }
    }

    /**
        Looks up a type within the type registry.

        Params:
            object = The object to look up
        
        Returns:
            The TypeId registered for the type,
            or $(D TypeId.nil) if it wasn't found.
    */
    TypeId lookup(T object) {
        if (object)
            return this.lookup(cast(TypeInfo)typeid(object));
        return TypeId.nil;
    }

    /**
        Looks up a type within the type registry.

        Params:
            object = The D typeid to look up.
        
        Returns:
            The TypeId registered for the type,
            or $(D TypeId.nil) if it wasn't found.
    */
    TypeId lookup(TypeInfo object) {
        if (cast(void*)object in typeIdStore)
            return typeIdStore[cast(void*)object];
        return TypeId.nil;
    }

    /**
        Gets whether the type registry has a given
        string ID registered within it.

        Params:
            sid = The string id to look up.
        
        Returns:
            $(D true) if the ID was found,
            $(D false) otherwise.
    */
    bool has(string sid) {
        return (sid in factoryStoreS) !is null;
    }

    /**
        Gets whether the type registry has a given
        numeric ID registered within it.

        Params:
            nid = The numeric id to look up.
        
        Returns:
            $(D true) if the ID was found,
            $(D false) otherwise.
    */
    bool has(uint nid) {
        return (nid in factoryStoreN) !is null;
    }

    /**
        Creates an instance of a type registered within
        the registry.

        Params:
            sid =   The string id to look up.
            args =  Arguments to pass to the constructor
        
        Returns:
            A new instance of the given type,
            $(D null) if not found.
    */
    T create(string sid, Args args) {
        if (sid in factoryStoreS)
            return factoryStoreS[sid](args);
        
        return fallbackFactory ? 
            fallbackFactory(args) : 
            T.init;
    }

    /**
        Creates an instance of a type registered within
        the registry.

        Params:
            nid =   The numeric id to look up.
            args =  Arguments to pass to the constructor
        
        Returns:
            A new instance of the given type,
            $(D null) if not found.
    */
    T create(uint nid, Args args) {
        if (nid in factoryStoreN)
            return factoryStoreN[nid](args);

        return fallbackFactory ? 
            fallbackFactory(args) : 
            T.init;
    }

    /**
        Allows iterating over the registry.

        Params:
            dg = The function to call on each iteration.
    */
    int opApply(scope int delegate(TypeId) dg) @nogc @trusted {
        return typeIdStore.opApply(dg);
    }

    /**
        Tries to create a type from the registry based on a DataNode.
        The DataNode must have a field called $(D type).

        Params:
            object =    The Object DataNode to deserialize from.
            args =      Arguments to pass to the type's constructor
        
        Returns:
            A newly allocated type based on the $(D type) tag,
            or $(D null) if this failed.
    */
    T tryCreateFrom(ref DataNode object, Args args) {
        if (object.isObject && "type" in object) {
            if (string type = object["type"].tryCoerce!string(null)) {
                if (!this.has(type))
                    return fallbackFactory ? 
                        fallbackFactory(args) : 
                        T.init;
                
                return this.create(type, args);
            }
        }
        return T.init;
    }
}