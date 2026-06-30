/*
    Inochi2D Mesh Effects

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.effect;
import inochi2d.core.math.deform;
import inochi2d.nodes.visual.part;
import inochi2d.core;
import inochi2d.common;
import inp.format;
import numem;

/**
    The public effect registry.
*/
__gshared TypeRegistry!(MeshEffect, Part) in_effect_registry;

/**
    Base class of effects that modify meshes.
*/
@TypeId("MeshEffect", 0x0000)
class MeshEffect : NuRefCounted, IDeserializable!ModelState {
private:
@nogc:
    Part parent_;

protected:

    /**
        Serializes this MeshEffect to a DataNode.

        Params:
            object =    The DataNode to serialize to.
    */
    void onSerialize(ref DataNode object) {
        object["type"] = in_effect_registry.lookup(this).sid;
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object =    The DataNode to deserialize from.
            state =     The state of the deserializer.
    */
    void onDeserialize(ref DataNode object, ref ModelState state) { }

    /**
        Called when the Effect is to be finalized during loading.

        Params:
            state =     The state of the deserializer.
    */
    void onFinalize(ref ModelState state) @nogc { }

    /**
        Called after the full node update cycle.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    void onApply(DrawList drawList) { }

public:

    /**
        The target of the effect.
    */
    @property Part parent() => parent_;

    /**
        Constructs a new mesh effect.

        Params:
            parent = The parent of the mesh effect.
    */
    this(Part parent) {
        this.parent_ = parent;
    }

    /**
        Serializes this mesh effect to a DataNode.

        Params:
            object =    The DataNode to serialize to.
    */
    final void serialize(ref DataNode object) @nogc {
        object = DataNode.createObject();
        this.onSerialize(object);
    }

    /**
        Deserializes this mesh effect from a DataNode.

        Params:
            object =    The DataNode to deserialize from.
            state =     The state of the deserializer.
    */
    final void deserialize(ref DataNode object, ref ModelState state) @nogc {
        this.onDeserialize(object, state);
    }

    /**
        Finalizes this mesh effect.

        Params:
            state =     The state of the deserializer.
    */
    final void finalize(ref ModelState state) @nogc {
        this.onFinalize(state);
    }

    /**
        Applies the late mesh effect, should be called after all of the
        normal node updates have completed.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    final void apply(DrawList drawList) {
        this.onApply(drawList);
    }
}
mixin Register!(MeshEffect, in_effect_registry);