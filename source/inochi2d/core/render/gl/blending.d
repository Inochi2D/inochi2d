module source.inochi2d.core.render.gl.blending;


private {
    bool inAdvancedBlending;
    bool inAdvancedBlendingCoherent;

    void inGLSetBlendModeLegacy(BlendMode blendingMode) {
        switch(blendingMode) {
            
            // If the advanced blending extension is not supported, force to Normal blending
            default:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;

            case BlendMode.Normal: 
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;

            case BlendMode.Multiply: 
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA); break;

            case BlendMode.Screen:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR); break;

            case BlendMode.Lighten:
                glBlendEquation(GL_MAX);
                glBlendFunc(GL_ONE, GL_ONE); break;

            case BlendMode.ColorDodge:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_DST_COLOR, GL_ONE); break;

            case BlendMode.LinearDodge:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_COLOR, GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;
                
            case BlendMode.AddGlow:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFuncSeparate(GL_ONE, GL_ONE, GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;

            case BlendMode.Subtract:
                glBlendEquationSeparate(GL_FUNC_REVERSE_SUBTRACT, GL_FUNC_ADD);
                glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ONE); break;

            case BlendMode.Exclusion:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFuncSeparate(GL_ONE_MINUS_DST_COLOR, GL_ONE_MINUS_SRC_COLOR, GL_ONE, GL_ONE); break;

            case BlendMode.Inverse:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA); break;
            
            case BlendMode.DestinationIn:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ZERO, GL_SRC_ALPHA); break;

            case BlendMode.ClipToLower:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_DST_ALPHA, GL_ONE_MINUS_SRC_ALPHA); break;

            case BlendMode.SliceFromLower:
                glBlendEquation(GL_FUNC_ADD);
                glBlendFunc(GL_ZERO, GL_ONE_MINUS_SRC_ALPHA); break;
        }
    }
}

/**
    Whether a multi-stage rendering pass should be used for blending
*/
bool inGLUseMultistageBlending(BlendMode blendingMode) {
    switch(blendingMode) {
        case BlendMode.Normal,
             BlendMode.LinearDodge,
             BlendMode.AddGlow,
             BlendMode.Subtract,
             BlendMode.Inverse,
             BlendMode.DestinationIn,
             BlendMode.ClipToLower,
             BlendMode.SliceFromLower:
                 return false;
        default: return hasKHRBlendEquationAdvanced;
    }
}

void inGLInitBlending() {
    
    if (hasKHRBlendEquationAdvanced) inAdvancedBlending = true;
    if (hasKHRBlendEquationAdvancedCoherent) inAdvancedBlendingCoherent = true;
    if (inAdvancedBlendingCoherent) glEnable(GL_BLEND_ADVANCED_COHERENT_KHR);
}

bool inGLIsAdvancedBlendMode(BlendMode mode) {
    if (!inAdvancedBlending) return false;
    switch(mode) {
        case BlendMode.Multiply:
        case BlendMode.Screen: 
        case BlendMode.Overlay: 
        case BlendMode.Darken: 
        case BlendMode.Lighten: 
        case BlendMode.ColorDodge: 
        case BlendMode.ColorBurn: 
        case BlendMode.HardLight: 
        case BlendMode.SoftLight: 
        case BlendMode.Difference: 
        case BlendMode.Exclusion: 
            return true;
        
        // Fallback to legacy
        default: 
            return false;
    }
}

void inGLSetBlendMode(BlendMode blendingMode, bool legacyOnly=false) {
    if (!inAdvancedBlending || legacyOnly) inSetBlendModeLegacy(blendingMode);
    else switch(blendingMode) {
        case BlendMode.Multiply: glBlendEquation(GL_MULTIPLY_KHR); break;
        case BlendMode.Screen: glBlendEquation(GL_SCREEN_KHR); break;
        case BlendMode.Overlay: glBlendEquation(GL_OVERLAY_KHR); break;
        case BlendMode.Darken: glBlendEquation(GL_DARKEN_KHR); break;
        case BlendMode.Lighten: glBlendEquation(GL_LIGHTEN_KHR); break;
        case BlendMode.ColorDodge: glBlendEquation(GL_COLORDODGE_KHR); break;
        case BlendMode.ColorBurn: glBlendEquation(GL_COLORBURN_KHR); break;
        case BlendMode.HardLight: glBlendEquation(GL_HARDLIGHT_KHR); break;
        case BlendMode.SoftLight: glBlendEquation(GL_SOFTLIGHT_KHR); break;
        case BlendMode.Difference: glBlendEquation(GL_DIFFERENCE_KHR); break;
        case BlendMode.Exclusion: glBlendEquation(GL_EXCLUSION_KHR); break;
        
        // Fallback to legacy
        default: inGLSetBlendModeLegacy(blendingMode); break;
    }
}

void inGLBlendModeBarrier(BlendMode mode) {
    if (inAdvancedBlending && !inAdvancedBlendingCoherent && inIsAdvancedBlendMode(mode)) 
        glBlendBarrierKHR();
}
