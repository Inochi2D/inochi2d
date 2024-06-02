/*
    Inochi2D Composite Node

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen, seagetch
*/
module inochi2d.core.nodes.composite.dcomposite;
import inochi2d.core.nodes.common;
import inochi2d.core.nodes;
import inochi2d.fmt;
import inochi2d.core;
import inochi2d.math;
import inochi2d;
import bindbc.opengl;
import std.exception;
import std.algorithm;
import std.algorithm.sorting;
import std.stdio;
import std.array;
import std.format;

package(inochi2d) {
    void inInitDComposite() {
        inRegisterNodeType!DynamicComposite;
    }
}

/**
    Composite Node
*/
@TypeId("DynamicComposite")
class DynamicComposite : Part {
protected:
    bool initialized = false;

public:
    this(bool delegatedMode) { }

    void selfSort() {
        import std.math : cmp;
        sort!((a, b) => cmp(
            a.zSort, 
            b.zSort) > 0)(subParts);
    }

    void scanPartsRecurse(ref Node node) {

        // Don't need to scan null nodes
        if (node is null) return;

        // Do the main check
        DynamicComposite dcomposite = cast(DynamicComposite)node;
        Composite composite = cast(Composite)node;
        Part part = cast(Part)node;
        if (part !is null && node != this) {
            subParts ~= part;
            part.ignorePuppet = ignorePuppet;
            if (dcomposite is null) {
                foreach(child; part.children) {
                    scanPartsRecurse(child);
                }
            } else {
                dcomposite.scanParts();
            }
            
        } else if ((dcomposite is null && composite is null) || node == this) {

            // Non-part nodes just need to be recursed through,
            // they don't draw anything.
            foreach(child; node.children) {
                scanPartsRecurse(child);
            }
        } else if (dcomposite !is null && node != this) {
            dcomposite.scanParts();
        } else if (composite !is null) {
            if (composite.delegated !is null) {
                subParts ~= composite.delegated;
            }
            composite.scanParts();
        }
    }

    // setup Children to project image to DynamicComposite
    //  - Part: ignore transform by puppet.
    //  - Compose: use internal DynamicComposite instead of Composite implementation.
    void setIgnorePuppetRecurse(Node node, bool ignorePuppet) {
        if (Part part = cast(Part)node) {
            part.ignorePuppet = ignorePuppet;
        } else if (Composite comp = cast(Composite)node) {
            if (ignorePuppet) {
                auto dcomposite = comp.delegated;
                if (comp.delegated is null) {
                    // Insert delegated DynamicComposite object to Composite Node.
                    dcomposite = new DynamicComposite(true);
                    dcomposite.name = "(%s)".format(comp.name);
                    dcomposite.setPuppet(puppet);
                    static if (1) {
                        // Insert Dynamic Composite in shadow mode.
                        // In this mode, parents and children are set to dcomposite in one-way manner.
                        // parent and children doesn't know dcomposite in their parent-children relationship.
                        Node* parent = &dcomposite.parent();
                        *parent = comp.parent;
                    } else {
                        // Debug mode:
                        // Insert Dynamic Composite as opaque mode.
                        // In this mode, parents and children are aware of inserted Dcomposite object in their tree hierarchy.
                        dcomposite.parent = comp.parent;
                    }

                    dcomposite.localTransform.translation = comp.localTransform.translation;
                }
                dcomposite.ignorePuppet = ignorePuppet;
                dcomposite.children_ref.length = 0;
                foreach (child; comp.children) {
                    dcomposite.children_ref ~= child;
                }
                dcomposite.setupSelf();
                comp.setDelegation(dcomposite);
            } else {
                // Remove delegated DynamicComposite.
                if (comp.delegated) {
                    comp.delegated.releaseSelf();
                }
                comp.setDelegation(null);
            }
        }
        foreach (child; node.children) {
            setIgnorePuppetRecurse(child, ignorePuppet);
        }
    }

    void setIgnorePuppet(bool ignorePuppet) {
        foreach (child; children) {
            setIgnorePuppetRecurse(child, ignorePuppet);
        }
        puppet.rescanNodes();
    }

    void drawSelf(bool isMask = false)() {
        super.drawSelf!isMask();
    }

protected:
    GLuint cfBuffer;
    GLint origBuffer;
    Texture stencil;
    GLint[4] origViewport;
    bool textureInvalidated = false;
    bool shouldUpdateVertices = false;

    uint texWidth = 0, texHeight = 0;
    vec2 autoResizedSize;
    int deferred = 0;

    vec3 prevTranslation;
    vec3 prevRotation;
    vec2 prevScale;
    bool deferredChanged = false;

    bool initTarget() {
        auto prevTexture = textures[0];
        auto prevStencil = stencil;

        updateBounds();
        auto bounds = this.bounds;
        uint width = cast(uint)((bounds.z-bounds.x) / transform.scale.x);
        uint height = cast(uint)((bounds.w-bounds.y) / transform.scale.y);
        if (width == 0 || height == 0) return false;

        texWidth = width + 1;
        texHeight = height + 1;
        textureOffset = vec2((bounds.x + bounds.z) / 2 - transform.translation.x, (bounds.y + bounds.w) / 2 - transform.translation.y);
//        textureOffset = (transform.matrix()*vec4((bounds.zw + bounds.xy) / 2, 0, 1)).xy;
        setIgnorePuppet(true);

        glGenFramebuffers(1, &cfBuffer);
        textures = [new Texture(texWidth, texHeight), null, null];
        stencil = new Texture(texWidth, texHeight, 1, true);

        glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &origBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, cfBuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textures[0].getTextureId(), 0);
        glClear(GL_COLOR_BUFFER_BIT);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_TEXTURE_2D, stencil.getTextureId(), 0);
        glClear(GL_STENCIL_BUFFER_BIT);

        // go back to default fb
        glBindFramebuffer(GL_FRAMEBUFFER, origBuffer);

        if (prevTexture !is null) {
            prevTexture.dispose();
        }
        if (prevStencil !is null) {
            prevStencil.dispose();
        }

        initialized = true;
        textureInvalidated = true;
        return true;
    }

    bool beginComposite() {
        if (shouldUpdateVertices) {
            shouldUpdateVertices = false;
        }

        if (!initialized) {
            if (!initTarget()) {
                return false;
            }
        }
        if (textureInvalidated || deferred > 0) {
            glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &origBuffer);
            glGetIntegerv(GL_VIEWPORT, cast(GLint*)origViewport);
            glBindFramebuffer(GL_FRAMEBUFFER, cfBuffer);
            inPushViewport(textures[0].width, textures[0].height);
            Camera camera = inGetCamera();
            camera.scale = vec2(1, -1);
            camera.position = (mat4.identity.scaling(transform.scale.x == 0 ? 0: 1/transform.scale.x, transform.scale.y == 0? 0: 1/transform.scale.y, 1) * mat4.identity.rotateZ(-transform.rotation.z) * -vec4(textureOffset, 0, 1)).xy;
            glViewport(0, 0, textures[0].width, textures[0].height);

            glDrawBuffers(3, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);
            glClearColor(0, 0, 0, 0);
            glClear(GL_COLOR_BUFFER_BIT);

            // Everything else is the actual texture used by the meshes at id 0
            glActiveTexture(GL_TEXTURE0);
            glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        }
        return textureInvalidated || deferred > 0;
    }
    void endComposite() {
        if (textureInvalidated) {
            textureInvalidated = false;
//            deferred = 3;  // continue rendering without any conditions for `deferred` frames by enabling this code.
        }
        if (deferred > 0)
            deferred --;

        glBindFramebuffer(GL_FRAMEBUFFER, origBuffer);
        inPopViewport();
        glViewport(origViewport[0], origViewport[1], origViewport[2], origViewport[3]);
        glDrawBuffers(3, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2].ptr);
        glFlush();
    }

    Part[] subParts;
    
    override
    string typeId() { return "DynamicComposite"; }

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void serializeSelfImpl(ref InochiSerializer serializer, bool recursive = true) {
        Texture[3] tmpTextures = textures;
        textures = [null, null, null];
        super.serializeSelfImpl(serializer, recursive);
        serializer.putKey("auto_resized");
        serializer.serializeValue(autoResizedMesh);
        textures = tmpTextures;
    }

    override
    SerdeException deserializeFromFghj(Fghj data) {
        auto result = super.deserializeFromFghj(data);
        textures = [null, null, null];
        if (!data["auto_resized"].isEmpty) 
            data["auto_resized"].deserializeValue(autoResizedMesh);
        else if (this.data.indices.length != 0) {
            autoResizedMesh = false;
        } else autoResizedMesh = true;
        return result;
    }

    vec4 getChildrenBounds() {
        if (subParts.length > 0) {
            float minX = (subParts.map!(p=> p.bounds.x).array).minElement();
            float minY = (subParts.map!(p=> p.bounds.y).array).minElement();
            float maxX = (subParts.map!(p=> p.bounds.z).array).maxElement();
            float maxY = (subParts.map!(p=> p.bounds.w).array).maxElement();
            return vec4(minX, minY, maxX, maxY);
        } else {
            return transform.translation.xyxy;
        }
    }

    bool createSimpleMesh() {
        auto newBounds = getChildrenBounds();
        vec2 origSize = shouldUpdateVertices? autoResizedSize: textures[0] !is null? vec2(textures[0].width, textures[0].height): vec2(0, 0);
        vec2 size = newBounds.zw - newBounds.xy;
        bool resizing = false;
        if (cast(int)origSize.x > cast(int)size.x) {
            float diff = (origSize.x - size.x) / 2;
            newBounds.z += diff;
            newBounds.x -= diff;
        } else if (cast(int)size.x > cast(int)origSize.x) {
            resizing = true;
        }
        if (cast(int)origSize.y > cast(int)size.y) {
            float diff = (origSize.y - size.y) / 2;
            newBounds.w += diff;
            newBounds.y -= diff;
        } else if (cast(int)size.y > cast(int)origSize.y) {
            resizing = true;
        }
        if (resizing) {
            MeshData newData = MeshData([
                vec2(newBounds.x, newBounds.y) - transform.translation.xy,
                vec2(newBounds.x, newBounds.w) - transform.translation.xy,
                vec2(newBounds.z, newBounds.y) - transform.translation.xy,
                vec2(newBounds.z, newBounds.w) - transform.translation.xy
            ], data.uvs = [
                vec2(0, 0),
                vec2(0, 1),
                vec2(1, 0),
                vec2(1, 1),
            ], data.indices = [
                0, 1, 2,
                2, 1, 3
            ], vec2(0, 0),[]);
            super.rebuffer(newData);
            shouldUpdateVertices = true;
            autoResizedSize = newBounds.zw - newBounds.xy;
            textureOffset = vec2((newBounds.x + newBounds.z) / 2 - transform.translation.x, (newBounds.y + newBounds.w) / 2 - transform.translation.y);
        } else {
//            auto newTextureOffset = (transform.matrix()*vec4((bounds.zw + bounds.xy) / 2, 0, 1)).xy;
            auto newTextureOffset = vec2((bounds.x + bounds.z) / 2 - transform.translation.x, (bounds.y + bounds.w) / 2 - transform.translation.y);
            if (newTextureOffset.x != textureOffset.x || newTextureOffset.y != textureOffset.y) {
                textureInvalidated = true;
                data.vertices = [
                    vec2(newBounds.x, newBounds.y) - transform.translation.xy,
                    vec2(newBounds.x, newBounds.w) - transform.translation.xy,
                    vec2(newBounds.z, newBounds.y) - transform.translation.xy,
                    vec2(newBounds.z, newBounds.w) - transform.translation.xy
                ];
                shouldUpdateVertices = true;
                autoResizedSize = newBounds.zw - newBounds.xy;
                // FIXME!: This updateVertices call is relatively slow, and createSimpleMesh is called everytime notifyChange is called.
                // To optimize performance, we should call updateVertices to a series of changes per parameters.
                // Currently, it produces nasty result when update vertices only once in every rendering loop. 
                updateVertices();
                textureOffset = vec2((bounds.x + bounds.z) / 2 - transform.translation.x, (bounds.y + bounds.w) / 2 - transform.translation.y);
            }
        }
        return resizing;
    }

public:
    vec2 textureOffset;
    bool autoResizedMesh = true;

    /**
        Constructs a new mask
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        Constructs a new composite
    */
    this(MeshData data, uint uuid, Node parent = null) {
        if (data.indices.length != 0) autoResizedMesh = false;
        super(data, uuid, parent);
    }

    @Ignore
    override
    Transform transform() {
        if (autoResizedMesh) {
            if (recalculateTransform) {
                localTransform.update();
                offsetTransform.update();

                if (lockToRoot())
                    globalTransform = localTransform.calcOffset(offsetTransform) * puppet.root.localTransform;
                else if (parent !is null)
                    globalTransform = localTransform.calcOffset(offsetTransform) * parent.transform;
                else
                    globalTransform = localTransform.calcOffset(offsetTransform);

                globalTransform.rotation = vec3(0, 0, 0);
                globalTransform.scale = vec2(1, 1);
                globalTransform.update();
                recalculateTransform = false;
            }

            return globalTransform;
        } else {
            return super.transform();
        }
    }


    override
    void update() {
        if (autoResizedMesh) {
            if (shouldUpdateVertices) {
                shouldUpdateVertices = false;
            }
            Node.update();
        } else super.update();
    }

    override
    void preProcess() {
        if (!autoResizedMesh) {
            super.preProcess();
        } else {
            Node.preProcess();
        }
    }

    override
    void postProcess() {
        if (!autoResizedMesh) {
            super.postProcess();
        } else {
            Node.postProcess();
        }
    }

    void drawContents() {
        // Optimization: Nothing to be drawn, skip context switching
        if (deferredChanged) {
            if (createSimpleMesh()) initialized = false;
            deferredChanged = false;
            textureInvalidated = true;
        }

        if (beginComposite()) {
            this.selfSort();
            mat4* origTransform = oneTimeTransform;
            mat4 tmpTransform = transform.matrix.inverse;
            Camera camera = inGetCamera();
            setOneTimeTransform(&tmpTransform);
            foreach(Part child; subParts) {
                child.drawOne();
            }
            setOneTimeTransform(origTransform);
            endComposite();
            textures[0].genMipmap();
        }
    }

    override
    void drawOne() {
        if (!enabled || puppet is null) return;
        this.drawContents();

        // No masks, draw normally
        drawSelf();
    }

    override
    void draw() {
        if (!enabled || puppet is null) return;
        this.drawOne();
    }


    /**
        Scans for parts to render
    */
    void scanParts() {
        subParts.length = 0;
        if (children.length > 0) {
            scanPartsRecurse(children[0].parent);
        }
    }

    void scanSubParts(Node[] childNodes) { 
        subParts.length = 0;
        foreach (child; childNodes) {
            scanPartsRecurse(child);
        }
    }

    override
    void setupChild(Node node) {
        setIgnorePuppetRecurse(node, true);
        puppet.rescanNodes();
    }

    override
    void releaseChild(Node node) {
        setIgnorePuppetRecurse(node, false);
        puppet.rescanNodes();
    }

    override
    void setupSelf() { 
        transformChanged();
        if (autoResizedMesh) {
            scanSubParts(children);
            if (createSimpleMesh()) initialized = false;
        }
        for (Node c = this; c !is null; c = c.parent) {
            c.addNotifyListener(&onAncestorChanged);
        }
    }

    override
    void releaseSelf() {
        for (Node c = this; c !is null; c = c.parent) {
            c.removeNotifyListener(&onAncestorChanged);
        }
    }

    // In autoResizedMesh mode, texture must be updated when any of the parents is translated, rotated, or scaled.
    // To detect parent's change, this object calls addNotifyListener to parents' event slot, and checks whether
    // they are changed or not.
    void onAncestorChanged(Node target, NotifyReason reason) {
        if (autoResizedMesh) {
            if (reason == NotifyReason.Transformed) {
                if (prevTranslation != transform.translation || prevRotation != transform.rotation || prevScale != transform.scale) {
                    deferredChanged = true;
                    prevTranslation = transform.translation;
                    prevRotation    = transform.rotation;
                    prevScale       = transform.scale;
                }
            }
        }
    }

    override
    void normalizeUV(MeshData* data) {
        import std.algorithm: map;
        import std.algorithm: minElement, maxElement;
        if (data.uvs.length != 0) {
            float minX = data.uvs.map!(a => a.x).minElement;
            float maxX = data.uvs.map!(a => a.x).maxElement;
            float minY = data.uvs.map!(a => a.y).minElement;
            float maxY = data.uvs.map!(a => a.y).maxElement;
            float width = maxX - minX;
            float height = maxY - minY;
            if (width < bounds.z - bounds.x) {
                width = bounds.z - bounds.x;
            }
            if (height < bounds.w - bounds.y) {
                width = bounds.w - bounds.y;
            }
            float centerX = (minX + maxX) / 2 / width;
            float centerY = (minY + maxY) / 2 / height;
            foreach(i; 0..data.uvs.length) {
                data.uvs[i].x /= width;
                data.uvs[i].y /= height;
                data.uvs[i] += vec2(0.5 - centerX, 0.5 - centerY);
            }
        }
    }

    override
    void notifyChange(Node target, NotifyReason reason = NotifyReason.Transformed) {
        if (target != this) {
            textureInvalidated = true;
        }
        if (autoResizedMesh) {
            if (createSimpleMesh()) {
                initialized = false;
            }
        }
        super.notifyChange(target, reason);
    }

    override
    void rebuffer(ref MeshData data) {
        if (data.vertices.length == 0) {
            autoResizedMesh = true;
        } else {
            autoResizedMesh = false;
        }

        super.rebuffer(data);
        initialized = false;
        setIgnorePuppet(false);
        notifyChange(this);
    }

    override
    void centralize() {
        super.centralize();
        vec4 bounds;
        vec4[] childTranslations;
        if (children.length > 0) {
            bounds = children[0].getCombinedBounds();
            foreach (child; children) {
                auto cbounds = child.getCombinedBounds();
                bounds.x = min(bounds.x, cbounds.x);
                bounds.y = min(bounds.y, cbounds.y);
                bounds.z = max(bounds.z, cbounds.z);
                bounds.w = max(bounds.w, cbounds.w);
                childTranslations ~= child.transform.matrix() * vec4(0, 0, 0, 1);
            }
        } else {
            bounds = transform.translation.xyxy;
        }
        vec2 center = (bounds.xy + bounds.zw) / 2;
        if (parent !is null) {
            center = (parent.transform.matrix.inverse * vec4(center, 0, 1)).xy;
        }
        auto diff = center - localTransform.translation.xy;
        localTransform.translation.x = center.x;
        localTransform.translation.y = center.y;
        if (!autoResizedMesh) {
            foreach (ref v; vertices) {
                v -= diff;
            }
            updateBounds();
            initialized = false;
        }
        transformChanged();
        foreach (i, child; children) {
            child.localTransform.translation = (transform.matrix.inverse * childTranslations[i]).xyz;
            child.transformChanged();
        }
        if (autoResizedMesh) {
            createSimpleMesh();
            updateBounds();
            initialized = false;
       }
    }

    override
    void copyFrom(Node src, bool inPlace = false, bool deepCopy = true) {
        super.copyFrom(src, inPlace, deepCopy);

        textures = [null, null, null];
        initialized = false;
        if (auto dcomposite = cast(DynamicComposite)src) {
            autoResizedMesh = dcomposite.autoResizedMesh;
            if (autoResizedMesh) {
                createSimpleMesh();
                updateBounds();
            }
        } else {
            autoResizedMesh = false;
            if (data.vertices.length == 0) {
                autoResizedMesh = true;
                createSimpleMesh();
                updateBounds();
            }
        }
        if (auto composite = cast(Composite)src) {
            blendingMode = composite.blendingMode;
            opacity = composite.opacity;
            autoResizedMesh = true;
            createSimpleMesh();
        }
    }

    void invalidate() { textureInvalidated = true; }

    override
    void build(bool force = false) {
        super.build(force);
        if (autoResizedMesh) {
            if (createSimpleMesh()) initialized = false;
        }
        if (force || !initialized) {
            initTarget();
        }
    }
}