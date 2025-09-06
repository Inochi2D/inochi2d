/**
    Shared core subsystem for type registration and instantiation.

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.registry;
import nulib;
import numem;

/**
    A UDA applied to types in Inochi2D to allow them to be instantiated
    using an object model. Types both may have a string and numeric ID.
*/
struct TypeId { 
    string  sid; 
    uint    nid;

    enum nil = TypeId(null, uint.max);
}

/**
    Tells the registry only to register the TypeId,
    but not the factories for a type.
*/
struct TypeIdAbstract;

/**
    Template which registers a type into a given type registry.
*/
mixin template Register(T, alias registry) {
    import numem.core.traits : hasUDA;
    static if (hasUDA!(T, TypeId)) {
        pragma(crt_constructor)
        mixin("extern(C) void __in_register_", T.stringof, "() { registry.register!T(); }");
    }
}

/**
    A type registry that stores mappings between name and numeric IDs
    and their classes.
*/
struct TypeRegistry(T) {
private:
    alias __TypeMap(Key, Value) = MapImpl!(Key, Value, (a, b) => a < b, false, false);
    alias __ctor(X) = () @nogc => assumeNoGC(() => cast(T)new X);

@nogc:
    alias factory_t = T function();
    __TypeMap!(void*,     TypeId)      typeIdStore;
    __TypeMap!(string, factory_t)    factoryStoreS;
    __TypeMap!(uint,   factory_t)    factoryStoreN;

public:

    /**
        Registers the given type in the type registry.

        Params:
            X = The object to register.
    */
    void register(X)() {
        import numem.core.traits : getUDAs, hasUDA;
        static assert(hasUDA!(X, TypeId), X.stringof~" does not have a TypeId UDA!");

        alias _tids = getUDAs!(X, TypeId);
        typeIdStore[cast(void*)typeid(X)] = _tids[0];

        static if (!hasUDA!(X, TypeIdAbstract)) {
            factoryStoreS[_tids[0].sid] = __ctor!X;
            factoryStoreN[_tids[0].nid] = __ctor!X;
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
        return this.lookup(cast(TypeInfo)typeid(object));
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
            sid = The string id to look up.
        
        Returns:
            A new instance of the given type,
            $(D null) if not found.
    */
    T create(string sid) {
        if (sid in factoryStoreS)
            return factoryStoreS[sid]();
        return null;
    }

    /**
        Creates an instance of a type registered within
        the registry.

        Params:
            nid = The numeric id to look up.
        
        Returns:
            A new instance of the given type,
            $(D null) if not found.
    */
    T create(uint nid) {
        if (nid in factoryStoreN)
            return factoryStoreN[nid]();
        return null;
    }

    /**
        Returns an iterator over all TypeIDs registered
        with the TypeRegistry.

        Returns:
            A forward range of all TypeId instances stored
            within this registry.
    */
    auto iterAll() {
        return typeIdStore.byValue();
    }
}