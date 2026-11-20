/**
    Material subsystem

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.resource.material;
import inochi2d.resource.texture;
import inochi2d.resource;
import inochi2d.config;
import inochi2d.core.property;
import numem;

public import inochi2d.resource.material.builtin;
public import inochi2d.resource.material.shader;

/**
    Pre-defined texture slot types.
*/
enum TextureSlot {

    /**
        Base unlit color of the material's surface.
    */
    albedo =    0,

    /**
        Normal map texture, defining the microfacets of the surface.
    */
    normal =    1,

    /**
        Emission map texture, defines the color and strength of light
        emitted from the surface.
    */
    emission =  2,

    /**
        Texture reserved for future use by the Inochi2D spec.
    */
    reserved0 = 3,
    reserved1 = 4, /// ditto.

    /**
        User-defined texture slot.
    */
    custom0 =   5,
    custom1 =   6, /// ditto
    custom2 =   7, /// ditto
}

enum : TextureSlot {

    /**
        Base unlit color of the material's surface.
    */
    TEXTURE_ALBEDO = TextureSlot.albedo,

    /**
        Normal map texture, defining the microfacets of the surface.
    */
    TEXTURE_NORMAL = TextureSlot.normal,

    /**
        Emission map texture, defines the color and strength of light
        emitted from the surface.
    */
    TEXTURE_EMSSION = TextureSlot.emission,

    /**
        Texture reserved for future use by the Inochi2D spec.
    */
    TEXTURE_RESERVED0 = TextureSlot.reserved0,
    TEXTURE_RESERVED1 = TextureSlot.reserved1, /// ditto

    /**
        User-defined texture slot.
    */
    TEXTURE_CUSTOM0 = TextureSlot.custom0,
    TEXTURE_CUSTOM1 = TextureSlot.custom1, /// ditto
    TEXTURE_CUSTOM2 = TextureSlot.custom2, /// ditto
}

/**
    Base class of materials, materials are a collection of shaders, textures
    and uniform variables.
*/
abstract
class Material : Resource, IPropertyOwner {
private:
@nogc:
    Texture[IN_MAX_ATTACHMENTS] textures_;
    PropertyStore props_;

protected:

    /**
        Called by the implementation when the material is to
        be initialized, define the material's properties here.

        Params:
            store = The backing property store.
    */
    abstract void onInitialize(ref PropertyStore store);

public:

    /**
        The textures attached to the material.
    */
    final @property Texture[] textures() => textures_[];

    /**
        Uniform variable data that can be copied to a GPU buffer.
    */
    final @property void[] uniforms() => props_.properties;

    /**
        Length of the resource's data allocation in bytes.
    */
    override @property size_t length() nothrow pure => props_.properties.length;

    /// Destructor
    ~this() {
        foreach(texture; textures_)
            if (texture)
                texture.release();
        nogc_zeroinit(textures_[]);
    }

    /**
        Constructs a new material.
    */
    this() {
        this.onInitialize(props_);
    }

    /**
        Sets the texture binding for a slot in the material.

        Params:
            slot =      The slot to assign the texture to.
            texture =   The texture to assign.
    */
    final void setTexture(uint slot, Texture texture) {
        assert(slot < IN_MAX_ATTACHMENTS, "Slot is out of range!");

        auto oldTexture = this.textures_[slot];
        this.textures_[slot] = texture.retained;
        if (oldTexture)
            oldTexture.release();
    }

    /**
        Gets whether a property with the given name exists
        in the object.

        Params:
            key = The name of the property.
        
        Returns:
            $(D true) if the property exists,
            $(D false) otherwise.
    */
    final bool hasProperty(quark key) const @nogc nothrow {
        return props_.offsetOf(key) != -1;
    }

    /**
        Gets the value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The floating point value of the property.
    */
    final float getProperty(quark key) const @nogc nothrow {
        return props_.get!float(key);
    }

    /**
        Gets the default value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The default value of the property.
    */
    final float getPropertyDefault(quark key) const @nogc nothrow {
        return props_.getDefault!float(key);
    }

    /**
        Sets the value of the property.

        Params:
            key =   The name of the property.
            value = The value to set the property to.
    */
    final void setProperty(quark key, float value) @nogc nothrow {
        props_.set!float(key, value);
    }

    /**
        Resets the given property.

        Params:
            key = The name of the property.
    */
    final void resetProperty(quark key) @nogc nothrow {
        props_.reset(key);
    }

    /**
        Resets all properties.
    */
    final void resetProperties() @nogc nothrow {
        props_.resetAll();
    }
}