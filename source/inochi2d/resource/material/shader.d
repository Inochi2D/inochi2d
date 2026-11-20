/**
    Inochi2D Shader Material

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.resource.material.shader;
import inochi2d.resource.material;
import inochi2d.resource.texture;
import inochi2d.core.property;

/**
    A material that applies a SPIR-V shader to the given part.
*/
class ShaderMaterial : Material {
private:
@nogc:
    uint[] vertexCode;
    uint[] fragmentCode;

protected:

    /**
        Called by the implementation when the material is to
        be initialized, define the material's properties here.

        Params:
            store = The backing property store.
    */
    override
    void onInitialize(ref PropertyStore store) {
        // TODO: Read uniforms from SPIR-V bytecode.
    }

public:
    
    this() {}    
}