/*
    Inochi2D Node

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes;
import inochi2d.math;
import inochi2d.fmt.serialize;
import inochi2d.math.serialization;
import inochi2d.core.dbg;
import inochi2d.core;

public import inochi2d.core.nodes.part;
public import inochi2d.core.nodes.mask;
public import inochi2d.core.nodes.drawable;
public import inochi2d.core.nodes.composite;
public import inochi2d.core.nodes.meshgroup;
public import inochi2d.core.nodes.drivers; 
import std.typecons: tuple, Tuple;

//public import inochi2d.core.nodes.shapes; // This isn't mainline yet!

import std.exception;

private {
    uint[] takenUUIDs;
}

package(inochi2d) {
    void inInitNodes() {
        inRegisterNodeType!Node;
        inRegisterNodeType!TmpNode;
    }
}

enum InInvalidUUID = uint.max;

/**
    Creates a new UUID for a node
*/
uint inCreateUUID() {
    import std.algorithm.searching : canFind;
    import std.random : uniform;

    uint id = uniform(uint.min, InInvalidUUID);
    while (takenUUIDs.canFind(id)) { id = uniform(uint.min, InInvalidUUID); } // Make sure the ID is actually unique in the current context

    return id;
}

/**
    Unloads a single UUID from the internal listing, freeing it up for reuse
*/
void inUnloadUUID(uint id) {
    import std.algorithm.searching : countUntil;
    import std.algorithm.mutation : remove;
    ptrdiff_t idx = takenUUIDs.countUntil(id);
    if (idx != -1) takenUUIDs.remove(idx);
}

/**
    Clears all UUIDs from the internal listing
*/
void inClearUUIDs() {
    takenUUIDs.length = 0;
}

/**
    A node in the Inochi2D rendering tree
*/
@TypeId("Node")
class Node : ISerializable {
private:

    @Ignore
    Puppet puppet_;

    @Ignore
    Node parent_;
    
    @Ignore
    Node[] children_;
    
    @Ignore
    uint uuid_;
    
    @Name("zsort")
    float zsort_ = 0;

    @Name("lockToRoot")
    bool lockToRoot_;

    @Ignore
    string nodePath_;

protected:
    this() { }

    bool preProcessed  = false;
    bool postProcessed = false;

    /**
        The offset to the transform to apply
    */
    Transform offsetTransform;

    /**
        The offset to apply to sorting
    */
    float offsetSort = 0f;

    // Send mask reset request one node up
    void resetMask() {
        if (parent !is null) parent.resetMask();
    }

    void serializeSelfImpl(ref InochiSerializer serializer, bool recursive=true) {
        
        serializer.putKey("uuid");
        serializer.putValue(uuid);
        
        serializer.putKey("name");
        serializer.putValue(name);
        
        serializer.putKey("type");
        serializer.putValue(typeId);
        
        serializer.putKey("enabled");
        serializer.putValue(enabled);
        
        serializer.putKey("zsort");
        serializer.putValue(zsort_);
        
        serializer.putKey("transform");
        serializer.serializeValue(this.localTransform);
        
        serializer.putKey("lockToRoot");
        serializer.serializeValue(this.lockToRoot_);
        
        if (recursive && children.length > 0) {
            serializer.putKey("children");
            auto childArray = serializer.arrayBegin();
            foreach(child; children) {

                // Skip Temporary nodes
                if (cast(TmpNode)child) continue;

                // Serialize permanent nodes
                serializer.elemBegin;
                serializer.serializeValue(child);
            }
            serializer.arrayEnd(childArray);
        }
    }

    void serializeSelf(ref InochiSerializer serializer) {
        serializeSelfImpl(serializer, true);
    }

    @Ignore
    mat4* oneTimeTransform = null;

    @Ignore
    class MatrixHolder {
    public:
        this(mat4 matrix) {
            this.matrix = matrix;
        }
        mat4 matrix;
    }
    MatrixHolder overrideTransformMatrix = null;

    Tuple!(vec2[], mat4*) delegate(vec2[], vec2[], mat4*) preProcessFilter  = null;
    Tuple!(vec2[], mat4*) delegate(vec2[], vec2[], mat4*) postProcessFilter = null;

    import std.stdio;
    void preProcess() {
        if (preProcessed)
            return;
        preProcessed = true;
        if (preProcessFilter !is null) {
            overrideTransformMatrix = null;
            mat4 matrix = this.parent? this.parent.transform.matrix: mat4.identity;
            auto filterResult = preProcessFilter([localTransform.translation.xy], [offsetTransform.translation.xy], &matrix);
            if (filterResult[0] !is null && filterResult[0].length > 0) {
                offsetTransform.translation = vec3(filterResult[0][0], offsetTransform.translation.z);
                transformChanged();
            } 
        }
    }

    void postProcess() {
        if (postProcessed)
            return;
        postProcessed = true;
        if (postProcessFilter !is null) {
            overrideTransformMatrix = null;
            mat4 matrix = this.parent? this.parent.transform.matrix: mat4.identity;
            auto filterResult = postProcessFilter([localTransform.translation.xy], [offsetTransform.translation.xy], &matrix);
            if (filterResult[0] !is null && filterResult[0].length > 0) {
                offsetTransform.translation = vec3(filterResult[0][0], offsetTransform.translation.z);
                transformChanged();
                overrideTransformMatrix = new MatrixHolder(transform.matrix);
            } 
        }
    }

package(inochi2d):

    /**
        Needed for deserialization
    */
    void setPuppet(Puppet puppet) {
        this.puppet_ = puppet;
    }

public:

    /**
        Whether the node is enabled
    */
    bool enabled = true;

    /**
        Whether the node is enabled for rendering

        Disabled nodes will not be drawn.

        This happens recursively
    */
    bool renderEnabled() {
        if (parent) return !parent.renderEnabled ? false : enabled;
        return enabled;
    }

    /**
        Visual name of the node
    */
    string name = "Unnamed Node";

    /**
        Name of node as a null-terminated C string
    */
    const(char)* cName() {
        import std.string : toStringz;
        return name.toStringz;
    }

    /**
        Returns the unique identifier for this node
    */
    uint uuid() {
        return uuid_;
    }

    /**
        This node's type ID
    */
    string typeId() { return "Node"; }

    /**
        Gets the relative Z sorting
    */
    ref float relZSort() {
        return zsort_;
    }

    /**
        Gets the basis zSort offset.
    */
    float zSortBase() {
        return parent !is null ? parent.zSort() : 0;
    }

    /**
        Gets the Z sorting without parameter offsets
    */
    float zSortNoOffset() {
        return zSortBase + relZSort;
    }

    /**
        Gets the Z sorting
    */
    float zSort() {
        return zSortBase + relZSort + offsetSort;
    }

    /**
        Sets the (relative) Z sorting
    */
    void zSort(float value) {
        zsort_ = value;
    }

    /**
        Lock translation to root
    */
    ref bool lockToRoot() {
        return lockToRoot_;
    }

    /**
        Lock translation to root
    */
    void lockToRoot(bool value) {
        
        // Automatically handle converting lock space and proper world space.
        if (value && !lockToRoot_) {
            localTransform.translation = transformNoLock().translation;
        } else if (!value && lockToRoot_) {
            localTransform.translation = localTransform.translation-parent.transformNoLock().translation;
        }

        lockToRoot_ = value;
    }

    /**
        Constructs a new puppet root node
    */
    this(Puppet puppet) {
        puppet_ = puppet;
    }

    /**
        Constructs a new node
    */
    this(Node parent = null) {
        this(inCreateUUID(), parent);
    }

    /**
        Constructs a new node with an UUID
    */
    this(uint uuid, Node parent = null) {
        this.parent = parent;
        this.uuid_ = uuid;
    }

    /**
        The local transform of the node
    */
    Transform localTransform;

    /**
        The cached world space transform of the node
    */
    @Ignore
    Transform globalTransform;

    @Ignore
    bool recalculateTransform = true;

    /**
        The transform in world space
    */
    @Ignore
    Transform transform(bool ignoreParam=false)() {
        if (recalculateTransform) {
            localTransform.update();
            offsetTransform.update();

            static if (!ignoreParam) {
                if (lockToRoot_)
                    globalTransform = localTransform.calcOffset(offsetTransform) * puppet.root.localTransform;
                else if (parent !is null)
                    globalTransform = localTransform.calcOffset(offsetTransform) * parent.transform();
                else
                    globalTransform = localTransform.calcOffset(offsetTransform);

                recalculateTransform = false;
            } else {

                if (lockToRoot_)
                    globalTransform = localTransform * puppet.root.localTransform;
                else if (parent !is null)
                    globalTransform = localTransform * parent.transform();
                else
                    globalTransform = localTransform;

                recalculateTransform = false;
            }
        }

        return globalTransform;
    }

    /**
        The transform in world space without locking
    */
    @Ignore
    Transform transformLocal() {
        localTransform.update();
        
        return localTransform.calcOffset(offsetTransform);
    }

    /**
        The transform in world space without locking
    */
    @Ignore
    Transform transformNoLock() {
        localTransform.update();
        
        if (parent !is null) return localTransform * parent.transform();
        return localTransform;
    }

    /**
        Calculates the relative position between 2 nodes and applies the offset.
        You should call this before reparenting nodes.
    */
    void setRelativeTo(Node to) {
        setRelativeTo(to.transformNoLock.matrix);
        this.zSort = this.zSortNoOffset-to.zSortNoOffset;
    }

    /**
        Calculates the relative position between this node and a matrix and applies the offset.
        This does not handle zSorting. Pass a Node for that.
    */
    void setRelativeTo(mat4 to) {
        this.localTransform.translation = getRelativePosition(to, this.transformNoLock.matrix);
        this.localTransform.update();
    }

    /**
        Gets a relative position for 2 matrices
    */
    static
    vec3 getRelativePosition(mat4 m1, mat4 m2) {
        mat4 cm = (m1.inverse * m2).translation;
        return vec3(cm.matrix[0][3], cm.matrix[1][3], cm.matrix[2][3]);
    }

    /**
        Gets a relative position for 2 matrices

        Inverse order of getRelativePosition
    */
    static
    vec3 getRelativePositionInv(mat4 m1, mat4 m2) {
        mat4 cm = (m2 * m1.inverse).translation;
        return vec3(cm.matrix[0][3], cm.matrix[1][3], cm.matrix[2][3]);
    }

    /**
        Gets the path to the node.
    */
    final
    string getNodePath() {
        import std.array : join;
        if (nodePath_.length > 0) return nodePath_;

        string[] pathSegments;
        Node parent = this;
        while(parent !is null) {
            pathSegments = parent.name ~ pathSegments;
            parent = parent.parent;
        }
        
        nodePath_ = "/"~pathSegments.join("/");
        return nodePath_;
    }

    /**
        Gets the depth of this node
    */
    final int depth() {
        int depthV;
        Node parent = this;
        while(parent !is null) {
            depthV++;
            parent = parent.parent;
        }
        return depthV;
    }

    /**
        Gets a list of this node's children
    */
    final Node[] children() {
        return children_;
    }

    /**
        Gets the parent of this node
    */
    final ref Node parent() {
        return parent_;
    }

    /**
        The puppet this node is attached to
    */
    final Puppet puppet() {
        return parent_ !is null ? parent_.puppet : puppet_;
    }

    /**
        Removes all children from this node
    */
    final void clearChildren() {
        foreach(child; children_) {
            child.parent_ = null;
        }
        this.children_ = [];
    }

    /**
        Adds a node as a child of this node.
    */
    final void addChild(Node child) {
        child.parent = this;
    }

    /**
        Sets the parent of this node
    */
    final void parent(Node node) {
        this.insertInto(node, OFFSET_END);
    }

    final ptrdiff_t getIndexInParent() {
        import std.algorithm.searching : countUntil;
        return parent_.children_.countUntil(this);
    }

    final ptrdiff_t getIndexInNode(Node n) {
        import std.algorithm.searching : countUntil;
        return n.children_.countUntil(this);
    }

    enum OFFSET_START = size_t.min;
    enum OFFSET_END = size_t.max;
    final void insertInto(Node node, size_t offset) {
        nodePath_ = null;
        import std.algorithm.mutation : remove;
        import std.algorithm.searching : countUntil;
        
        // Remove ourselves from our current parent if we are
        // the child of one already.
        if (parent_ !is null) {
            
            // Try to find ourselves in our parent
            // note idx will be -1 if we can't be found
            ptrdiff_t idx = parent_.children_.countUntil(this);
            assert(idx >= 0, "Invalid parent-child relationship!");

            // Remove ourselves
            parent_.children_ = parent_.children_.remove(idx);
        }

        // If we want to become parentless we need to handle that
        // seperately, as null parents have no children to update
        if (node is null) {
            this.parent_ = null;
            return;
        }

        // Update our relationship with our new parent
        this.parent_ = node;

        // Update position
        if (offset == OFFSET_START) {
            this.parent_.children_ = this ~ this.parent_.children_;
        } else if (offset == OFFSET_END || offset >= parent_.children_.length) {
            this.parent_.children_ ~= this;
        } else {
            this.parent_.children_ = this.parent_.children_[0..offset] ~ this ~ this.parent_.children_[offset..$];
        }
        if (this.puppet !is null) this.puppet.rescanNodes();
    }

    /**
        Return whether this node supports a parameter
    */
    bool hasParam(string key) {
        switch(key) {
            case "zSort":
            case "transform.t.x":
            case "transform.t.y":
            case "transform.t.z":
            case "transform.r.x":
            case "transform.r.y":
            case "transform.r.z":
            case "transform.s.x":
            case "transform.s.y":
                return true;
            default:
                return false;
        }
    }

    /**
        Gets the default offset value
    */
    float getDefaultValue(string key) {
        switch(key) {
            case "zSort":
            case "transform.t.x":
            case "transform.t.y":
            case "transform.t.z":
            case "transform.r.x":
            case "transform.r.y":
            case "transform.r.z":
                return 0;
            case "transform.s.x":
            case "transform.s.y":
                return 1;
            default:
                return float();
        }
    }

    /**
        Sets offset value
    */
    bool setValue(string key, float value) {
        switch(key) {
            case "zSort":
                offsetSort += value;
                return true;
            case "transform.t.x":
                offsetTransform.translation.x += value;
                transformChanged();
                return true;
            case "transform.t.y":
                offsetTransform.translation.y += value;
                transformChanged();
                return true;
            case "transform.t.z":
                offsetTransform.translation.z += value;
                transformChanged();
                return true;
            case "transform.r.x":
                offsetTransform.rotation.x += value;
                transformChanged();
                return true;
            case "transform.r.y":
                offsetTransform.rotation.y += value;
                transformChanged();
                return true;
            case "transform.r.z":
                offsetTransform.rotation.z += value;
                transformChanged();
                return true;
            case "transform.s.x":
                offsetTransform.scale.x *= value;
                transformChanged();
                return true;
            case "transform.s.y":
                offsetTransform.scale.y *= value;
                transformChanged();
                return true;
            default: return false;
        }
    }

    /**
        Scale an offset value, given an axis and a scale

        If axis is -1, apply magnitude and sign to signed properties.
        If axis is 0 or 1, apply magnitude only unless the property is
        signed and aligned with that axis.

        Note that scale adjustments are not considered aligned,
        since we consider preserving aspect ratio to be the user
        intent by default.
    */
    float scaleValue(string key, float value, int axis, float scale) {
        if (axis == -1) return value * scale;

        float newVal = abs(scale) * value;
        switch(key) {
            case "transform.r.z": // Z-rotation is XY-mirroring
                newVal = scale * value;
                break;
            case "transform.r.y": // Y-rotation is X-mirroring
            case "transform.t.x":
                if (axis == 0) newVal = scale * value;
                break;
            case "transform.r.x": // X-rotation is Y-mirroring
            case "transform.t.y":
                if (axis == 1) newVal = scale * value;
                break;
            default:
                break;
        }
        return newVal;
    }

    float getValue(string key) {
        switch(key) {
            case "zSort":           return offsetSort;
            case "transform.t.x":   return offsetTransform.translation.x;
            case "transform.t.y":   return offsetTransform.translation.y;
            case "transform.t.z":   return offsetTransform.translation.z;
            case "transform.r.x":   return offsetTransform.rotation.x;
            case "transform.r.y":   return offsetTransform.rotation.y;
            case "transform.r.z":   return offsetTransform.rotation.z;
            case "transform.s.x":   return offsetTransform.scale.x;
            case "transform.s.y":   return offsetTransform.scale.y;
            default:                return 0;
        }
    }

    /**
        Draws this node and it's subnodes
    */
    void draw() {
        if (!renderEnabled) return;

        foreach(child; children) {
            child.draw();
        }
    }

    /**
        Draws this node.
    */
    void drawOne() { }


    void reconstruct() {
        foreach(child; children.dup) {
            child.reconstruct();
        }
    }

    /**
        Finalizes this node and any children
    */
    void finalize() {
        foreach(child; children) {
            child.finalize();
        }
    }

    void beginUpdate() {
        preProcessed  = false;
        postProcessed = false;

        offsetSort = 0;
        offsetTransform.clear();

        // Iterate through children
        foreach(child; children_) {
            child.beginUpdate();
        }
    }

    /**
        Updates the node
    */
    void update() {
        preProcess();

        if (!enabled) return;

        foreach(child; children) {
            child.update();
        }
    }

    /**
        Complete update
    */
    void endUpdate() {
        postProcess();
        foreach(child; children) {
            child.endUpdate();
        }
    }

    /**
        Marks this node's transform (and its descendents') as dirty
    */
    void transformChanged() {
        recalculateTransform = true;

        foreach(child; children) {
            child.transformChanged();
        }
    }

    override
    string toString() {
        return name;
    }

    /**
        Allows serializing a node (with pretty serializer)
    */
    void serialize(S)(ref S serializer) {
        auto state = serializer.objectBegin();
            this.serializeSelf(serializer);
        serializer.objectEnd(state);
    }

    /**
        Deserializes node from Fghj formatted JSON data.
    */
    SerdeException deserializeFromFghj(Fghj data) {

        if (auto exc = data["uuid"].deserializeValue(this.uuid_)) return exc;

        if (!data["name"].isEmpty) {
            if (auto exc = data["name"].deserializeValue(this.name)) return exc;
        }

        if (auto exc = data["enabled"].deserializeValue(this.enabled)) return exc;

        if (auto exc = data["zsort"].deserializeValue(this.zsort_)) return exc;
        
        if (auto exc = data["transform"].deserializeValue(this.localTransform)) return exc;
        
        if (!data["lockToRoot"].isEmpty) {
            if (auto exc = data["lockToRoot"].deserializeValue(this.lockToRoot_)) return exc;
        }

        // Pre-populate our children with the correct types
        foreach(child; data["children"].byElement) {
            
            // Fetch type from json
            string type;
            if (auto exc = child["type"].deserializeValue(type)) return exc;
            
            // Skips unknown node types
            // TODO: A logging system that shows a warning for this?
            if (!inHasNodeType(type)) continue;

            // instantiate it
            Node n = inInstantiateNode(type, this);
            if (auto exc = child.deserializeValue(n)) return exc;
        }


        return null;
    }

    void serializePartial(ref InochiSerializer serializer, bool recursive = true) {
        serializeSelfImpl(serializer, recursive);
    }

    /**
        Force sets the node's ID

        THIS IS NOT A SAFE OPERATION.
    */
    final void forceSetUUID(uint uuid) {
        this.uuid_ = uuid;
    }

    rect getCombinedBoundsRect(bool reupdate = false, bool countPuppet=false)() {
        vec4 combinedBounds = getCombinedBounds!(reupdate, countPuppet)();
        return rect(
            combinedBounds.x, 
            combinedBounds.y, 
            combinedBounds.z-combinedBounds.x, 
            combinedBounds.w-combinedBounds.y
        );
    }

    vec4 getInitialBoundsSize() {
        auto tr = transform;
        return vec4(tr.translation.x, tr.translation.y, tr.translation.x, tr.translation.y);
    }

    /**
        Gets the combined bounds of the node
    */
    vec4 getCombinedBounds(bool reupdate = false, bool countPuppet=false)() {
        vec4 combined = getInitialBoundsSize();
        
        // Get Bounds as drawable
        if (Drawable drawable = cast(Drawable)this) {
            if (reupdate) drawable.updateBounds();
            combined = drawable.bounds;
        }

        foreach(child; children) {
            vec4 cbounds = child.getCombinedBounds!(reupdate)();
            if (cbounds.x < combined.x) combined.x = cbounds.x;
            if (cbounds.y < combined.y) combined.y = cbounds.y;
            if (cbounds.z > combined.z) combined.z = cbounds.z;
            if (cbounds.w > combined.w) combined.w = cbounds.w;
        }

        static if (countPuppet) {
            return vec4(
                (puppet.transform.matrix*vec4(combined.xy, 0, 1)).xy,
                (puppet.transform.matrix*vec4(combined.zw, 0, 1)).xy,
            );
        } else {
            return combined;
        }
    }

    /**
        Gets whether nodes can be reparented
    */
    bool canReparent(Node to) {
        Node tmp = to;
        while(tmp !is null) {
            if (tmp.uuid == this.uuid) return false;
            
            // Check next up
            tmp = tmp.parent;
        }
        return true;
    }

    /**
        Draws orientation of the node
    */
    void drawOrientation() {
        auto trans = transform.matrix();
        inDbgLineWidth(4);

        // X
        inDbgSetBuffer([vec3(0, 0, 0), vec3(32, 0, 0)], [0, 1]);
        inDbgDrawLines(vec4(1, 0, 0, 0.7), trans);

        // Y
        inDbgSetBuffer([vec3(0, 0, 0), vec3(0, -32, 0)], [0, 1]);
        inDbgDrawLines(vec4(0, 1, 0, 0.7), trans);
        
        // Z
        inDbgSetBuffer([vec3(0, 0, 0), vec3(0, 0, -32)], [0, 1]);
        inDbgDrawLines(vec4(0, 0, 1, 0.7), trans);

        inDbgLineWidth(1);
    }

    /**
        Draws bounds
    */
    void drawBounds() {
        vec4 bounds = this.getCombinedBounds;

        float width = bounds.z-bounds.x;
        float height = bounds.w-bounds.y;
        inDbgSetBuffer([
            vec3(bounds.x, bounds.y, 0),
            vec3(bounds.x + width, bounds.y, 0),
            
            vec3(bounds.x + width, bounds.y, 0),
            vec3(bounds.x + width, bounds.y+height, 0),
            
            vec3(bounds.x + width, bounds.y+height, 0),
            vec3(bounds.x, bounds.y+height, 0),
            
            vec3(bounds.x, bounds.y+height, 0),
            vec3(bounds.x, bounds.y, 0),
        ]);
        inDbgLineWidth(3);
        inDbgDrawLines(vec4(.5, .5, .5, 1));
        inDbgLineWidth(1);
    }


    void setOneTimeTransform(mat4* transform) {
        oneTimeTransform = transform;

        foreach (c; children) {
            c.setOneTimeTransform(transform);
        }
    }

    mat4* getOneTimeTransform() {
        return oneTimeTransform;
    }

    /** 
     * set new Parent
     */
    void reparent(Node parent, ulong pOffset) {
        void unsetGroup(Node node) {
            node.postProcessFilter = null;
            node.preProcessFilter  = null;
            auto group = cast(MeshGroup)node;
            if (group is null) {
                foreach (child; node.children) {
                    unsetGroup(child);
                }
            }
        }

        unsetGroup(this);

        if (parent !is null)
            setRelativeTo(parent);
        insertInto(parent, pOffset);
        auto c = this;
        for (auto p = parent; p !is null; p = p.parent, c = c.parent) {
            p.setupChild(c);
        }
    }

    void setupChild(Node child) { }

    mat4 getDynamicMatrix() {
        if (overrideTransformMatrix !is null) {
            return overrideTransformMatrix.matrix;
        } else {
            return transform.matrix;
        }
    }
}

//
//  TEMPORARY NODE
//

/**
    A temporary node which will not be saved to file under any circumstances
*/
@TypeId("Tmp")
class TmpNode : Node {
protected:
    override
    string typeId() { return "Tmp"; }

public:
    this() { super(); }
    this(Node parent) { super(parent); }
}


//
//  SERIALIZATION SHENNANIGANS
//
private {
    Node delegate(Node parent)[string] typeFactories;

    Node inInstantiateNode(string id, Node parent = null) {
        return typeFactories[id](parent);
    }
}

void inRegisterNodeType(T)() if (is(T : Node)) {
    import std.traits : getUDAs;
    typeFactories[getUDAs!(T, TypeId)[0].id] = (Node parent) {
        return new T(parent);
    };
}

/**
    Gets whether a node type is present in the factories
*/
bool inHasNodeType(string id) {
    return (id in typeFactories) !is null;
}

mixin template InNode(T) {
    static this() {
        inRegisterNodeType!(T);
    }
}