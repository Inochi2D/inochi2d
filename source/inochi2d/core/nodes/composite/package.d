/*
    Inochi2D Composite Node

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.composite;
import inochi2d.core.nodes.drawable;
import inochi2d.core.nodes;
import inochi2d.core.math;
import inochi2d.core;

import std.exception;

public import inochi2d.core.render.state;
import numem;

struct CompositeVars {
align(vec4.sizeof):
    vec3 tint;
    vec3 screenTint;
    float opacity;
}

/**
    Composite Node
*/
@TypeId("Composite", 0x0004)
class Composite : Node {
private:
    DrawListAlloc* __screenSpaceAlloc;
    Mesh __screenSpaceMesh;

    void setupScreenSpaceMesh() {
        if (!__screenSpaceMesh) {
            MeshData tmp;
            tmp.indices = [
                0, 1, 2,
                2, 1, 3
            ];
            tmp.uvs = [
                vec2(0, 0),
                vec2(0, 1),
                vec2(1, 0),
                vec2(1, 1)
            ];
            tmp.vertices = [
                vec2(-1, -1),
                vec2(-1,  1),
                vec2(1,  -1),
                vec2(1,   1)
            ];
            __screenSpaceMesh = Mesh.fromMeshData(tmp);
        }
    }

    void selfSort() {
        import std.algorithm.sorting : sort;
        import std.algorithm.mutation : SwapStrategy;
        import std.math : cmp;
        
        sort!((a, b) => cmp(
            a.zSort, 
            b.zSort) > 0, SwapStrategy.stable)(toRender);
    }

    void scanPartsRecurse(Node node) {

        // Don't need to scan null nodes
        if (node is null) return;

        // Do the main check
        if (Drawable drawable = cast(Drawable)node) {
            if (!drawable.renderEnabled)
                return;
            
            toRender ~= drawable;
            foreach(child; drawable.children) {
                scanPartsRecurse(child);
            }
        } else if (Composite composite = cast(Composite)node) {
            if (!composite.renderEnabled)
                return;
            
            toRender ~= composite;
        } else {

            // Non-part nodes just need to be recursed through,
            // they don't draw anything.
            foreach(child; node.children) {
                scanPartsRecurse(child);
            }
        }
    }

protected:
    Node[] toRender;

    override
    void onSerialize(ref JSONValue object, bool recursive=true) {
        super.onSerialize(object, recursive);
        object["blend_mode"] = blendingMode;
        object["tint"] = tint.serialize();
        object["screenTint"] = screenTint.serialize();
        object["opacity"] = opacity;
        object["propagate_meshgroup"] = propagateMeshGroup;
        object["masks"] = masks.serialize();
    }

    override
    void onDeserialize(ref JSONValue object) {
        super.onDeserialize(object);

        object.tryGetRef(opacity, "opacity");
        object.tryGetRef(tint, "tint");
        object.tryGetRef(screenTint, "screenTint");
        object.tryGetRef(masks, "masks");
        object.tryGetRef(propagateMeshGroup, "propagate_meshgroup", false);
        blendingMode = object.tryGet!string("blend_mode", "Normal").toBlendMode();
    }

    override
    void finalize() {
        super.finalize();
        
        MaskBinding[] validMasks;
        foreach(i; 0..masks.length) {
            if (Drawable nMask = puppet.find!Drawable(masks[i].maskSrcGUID)) {
                masks[i].maskSrc = nMask;
                validMasks ~= masks[i];
            }
        }

        // Remove invalid masks
        masks = validMasks;
    }

    //
    //      PARAMETER OFFSETS
    //
    float offsetOpacity = 1;
    vec3 offsetTint = vec3(0);
    vec3 offsetScreenTint = vec3(0);

    // TODO: Cache this
    size_t maskCount() {
        size_t c;
        foreach(m; masks) if (m.mode == MaskingMode.mask) c++;
        return c;
    }

    size_t dodgeCount() {
        size_t c;
        foreach(m; masks) if (m.mode == MaskingMode.dodge) c++;
        return c;
    }

public:
    bool propagateMeshGroup = true;

    /**
        The blending mode
    */
    BlendMode blendingMode;

    /**
        The opacity of the composite
    */
    float opacity = 1;

    /**
        Multiplicative tint color
    */
    vec3 tint = vec3(1, 1, 1);

    /**
        Screen tint color
    */
    vec3 screenTint = vec3(0, 0, 0);

    /**
        List of masks to apply
    */
    MaskBinding[] masks;

    /// Destructor
    ~this() { }

    /**
        Constructs a new mask
    */
    this(Node parent = null) {
        this(inNewGUID(), parent);
    }

    /**
        Constructs a new composite
    */
    this(GUID guid, Node parent = null) {
        super(guid, parent);
        this.setupScreenSpaceMesh();
    }

    override
    bool hasParam(string key) {
        if (super.hasParam(key)) return true;

        switch(key) {
            case "opacity":
            case "tint.r":
            case "tint.g":
            case "tint.b":
            case "screenTint.r":
            case "screenTint.g":
            case "screenTint.b":
                return true;
            default:
                return false;
        }
    }

    override
    float getDefaultValue(string key) {
        // Skip our list of our parent already handled it
        float def = super.getDefaultValue(key);
        if (def.isFinite) return def;

        switch(key) {
            case "opacity":
            case "tint.r":
            case "tint.g":
            case "tint.b":
                return 1;
            case "screenTint.r":
            case "screenTint.g":
            case "screenTint.b":
                return 0;
            default: return float();
        }
    }

    override
    bool setValue(string key, float value) {
        
        // Skip our list of our parent already handled it
        if (super.setValue(key, value)) return true;

        switch(key) {
            case "opacity":
                offsetOpacity *= value;
                return true;
            case "tint.r":
                offsetTint.x *= value;
                return true;
            case "tint.g":
                offsetTint.y *= value;
                return true;
            case "tint.b":
                offsetTint.z *= value;
                return true;
            case "screenTint.r":
                offsetScreenTint.x += value;
                return true;
            case "screenTint.g":
                offsetScreenTint.y += value;
                return true;
            case "screenTint.b":
                offsetScreenTint.z += value;
                return true;
            default: return false;
        }
    }
    
    override
    float getValue(string key) {
        switch(key) {
            case "opacity":         return offsetOpacity;
            case "tint.r":          return offsetTint.x;
            case "tint.g":          return offsetTint.y;
            case "tint.b":          return offsetTint.z;
            case "screenTint.r":    return offsetScreenTint.x;
            case "screenTint.g":    return offsetScreenTint.y;
            case "screenTint.b":    return offsetScreenTint.z;
            default:                return super.getValue(key);
        }
    }

    bool isMaskedBy(Drawable drawable) {
        foreach(mask; masks) {
            if (mask.maskSrc.guid == drawable.guid) return true;
        }
        return false;
    }

    ptrdiff_t getMaskIdx(Drawable drawable) {
        if (drawable is null) return -1;
        foreach(i, ref mask; masks) {
            if (mask.maskSrc.guid == drawable.guid) return i;
        }
        return -1;
    }

    ptrdiff_t getMaskIdx(GUID guid) {
        foreach(i, ref mask; masks) {
            if (mask.maskSrc.guid == guid) return i;
        }
        return -1;
    }

    override
    void preUpdate(DrawList drawList) {
        super.preUpdate(drawList);
        __screenSpaceAlloc = null;

        offsetOpacity = 1;
        offsetTint = vec3(1, 1, 1);
        offsetScreenTint = vec3(0, 0, 0);
    }

    override
    void update(float delta, DrawList drawList) {
        super.update(delta, drawList);

        // Avoid over allocating a single screenspace
        // rect.
        if (!__screenSpaceAlloc)
            __screenSpaceAlloc = drawList.allocate(__screenSpaceMesh.vertices, __screenSpaceMesh.indices);
    }

    override
    void draw(float delta, DrawList drawList) {
        if (!renderEnabled || toRender.length == 0)
            return;
        
        CompositeVars compositeVars = CompositeVars(
            tint*offsetTint,
            screenTint*offsetScreenTint,
            opacity*offsetOpacity
        );

        this.selfSort();

        // Push sub render area.
        drawList.beginComposite();
            foreach(Node child; toRender) {
                child.draw(delta, drawList);
            }
        drawList.endComposite();

        if (masks.length > 0) {
            foreach(ref mask; masks) {
                mask.maskSrc.drawAsMask(delta, drawList, mask.mode);
            }
        }

        // Then blit it to the main framebuffer
        drawList.setVariables!CompositeVars(nid, compositeVars);
        drawList.setMesh(__screenSpaceAlloc);
        drawList.setDrawState(DrawState.compositeBlit);
        drawList.setBlending(blendingMode);
        drawList.next();
    }

    /**
        Scans for parts to render
    */
    void scanParts() {
        toRender.length = 0;
        foreach(child; children) {
            scanPartsRecurse(child);
        }
    }
}
mixin Register!(Composite, in_node_registry);