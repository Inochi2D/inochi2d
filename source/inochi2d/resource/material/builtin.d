/**
    Inochi2D Builtin material.

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.resource.material.builtin;
import inochi2d.resource.material;
import inochi2d.resource.texture;
import inochi2d.core.property;
import nulib.quark;
import numath;

/**
    Builtin material with no attached shader, builtin shader is defined
    elsewhere and the variables are just provided.
*/
class BuiltinMaterial : Material {
protected:
@nogc:

    /**
        Called by the implementation when the material is to
        be initialized, define the material's properties here.

        Params:
            store = The backing property store.
    */
    override
    void onInitialize(ref PropertyStore store) {
        store.define!float(PROP_SCREEN_R, 0);
        store.define!float(PROP_SCREEN_G, 0);
        store.define!float(PROP_SCREEN_B, 0);
        store.pad(4);
        store.define!float(PROP_TINT_R, 1);
        store.define!float(PROP_TINT_G, 1);
        store.define!float(PROP_TINT_B, 1);
        store.pad(4);
        store.define!float(PROP_OPACITY, 1);
        store.define!float(PROP_EMISSION_STRENGTH, 1);

        // Define combined overlays.
        store.defineOverlay!vec3(PROP_SCREEN_RGB, store.offsetOf(PROP_SCREEN_R));
        store.defineOverlay!vec3(PROP_TINT_RGB, store.offsetOf(PROP_TINT_R));
    }
}
// dfmt off




//
//          QUARKS
//

mixin RegisterQuarks!();

/**
    z-sort value.
*/
@propkey("zsort")
__gshared immutable(quark) PROP_ZSORT;

/**
    Opacity.
*/
@propkey("opacity")
__gshared immutable(quark) PROP_OPACITY;

/**
    Tint RGB
*/
@propkey("tint.rgb")
__gshared immutable(quark) PROP_TINT_RGB;

/**
    Tint red
*/
@propkey("tint.r")
__gshared immutable(quark) PROP_TINT_R;

/**
    Tint green
*/
@propkey("tint.g")
__gshared immutable(quark) PROP_TINT_G;

/**
    Tint blue
*/
@propkey("tint.b")
__gshared immutable(quark) PROP_TINT_B;

/**
    Screen-tint RGB
*/
@propkey("screenTint.rgb")
__gshared immutable(quark) PROP_SCREEN_RGB;

/**
    Screen-tint red
*/
@propkey("screenTint.r")
__gshared immutable(quark) PROP_SCREEN_R;

/**
    Screen-tint green
*/
@propkey("screenTint.g")
__gshared immutable(quark) PROP_SCREEN_G;

/**
    Screen-tint blue
*/
@propkey("screenTint.b")
__gshared immutable(quark) PROP_SCREEN_B;

/**
    Emission strength
*/
@propkey("emissionStrength")
__gshared immutable(quark) PROP_EMISSION_STRENGTH;