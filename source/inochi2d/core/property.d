/**
    Inochi2D Properties

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.property;
import numem.core.meta;
import numem.core.traits;

/**
    A type which contains properties.
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
    bool hasProperty(string key) const;

    /**
        Gets the value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The floating point value of the property.
    */
    float getProperty(string key) const;

    /**
        Gets the default value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The default value of the property.
    */
    float getPropertyDefault(string key) const;

    /**
        Sets the value of the property.

        Params:
            key =   The name of the property.
            value = The value to set the property to.
    */
    void setProperty(string key, float value);
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
