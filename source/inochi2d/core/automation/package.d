/*
    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.automation;
import inochi2d.fmt.serde;
import inochi2d.core.math;
import inochi2d.core;
import inochi2d;

/**
    Automation binding
*/
struct AutomationBinding {
    
    /**
        Used for serialization.
        Name of parameter
    */
    string paramId;

    /**
        Parameter to bind to
    */
    Parameter param;

    /**
        Axis to bind to
        0 = X
        1 = Y
    */
    int axis;

    /**
        Min/max range of binding
    */
    vec2 range;

    /**
        Gets the value at the specified axis
    */
    float getAxisValue() {
        switch(axis) {
            case 0:
                return param.value.x;
            case 1:
                return param.value.y;
            default: return float.nan;
        }
    }

    /**
        Sets axis value (WITHOUT REMAPPING)
    */
    void setAxisValue(float value) {
        switch(axis) {
            case 0:
                param.value.x = value;
                break;
            case 1:
                param.value.y = value;
                break;
            default: assert(0);
        }
    }

    /**
        Sets axis value (WITHOUT REMAPPING)
    */
    void addAxisOffset(float value) {
        param.pushIOffsetAxis(axis, value);
    }

    /**
        Serializes a parameter
    */
    void onSerialize(ref JSONValue object) {
        object["param"] = this.paramId;
        object["axis"] = axis;
        object["range"] = range.serialize();
    }

    /**
        Deserializes a parameter
    */
    void onDeserialize(ref JSONValue object) {
        object.tryGetRef(paramId, "param");
        object.tryGetRef(axis, "axis");
        object.tryGetRef(range, "range");
    }

    void reconstruct(Puppet puppet) { }

    void finalize(Puppet puppet) {
        foreach(ref parameter; puppet.parameters) {
            if (parameter.name == paramId) {
                param = parameter;
                return;
            }
        }
    }

}

class Automation {
private:
    Puppet parent;

protected:

    AutomationBinding[] bindings;

    /**
        Helper function to remap range from 0.0-1.0
        to min-max
    */
    final
    float remapRange(float value, vec2 range) {
        return range.x + value * (range.y - range.x);
    }

    /**
        Called on update to update a single binding.

        Use currTime() to get the current time
        Use deltaTime() to get delta time
        Use binding.range to get the range to apply the automation within.
    */
    void onUpdate() { }

    void serializeSelf(ref JSONValue object) { }
    void deserializeSelf(ref JSONValue object) { }

public:
    /**
        Human readable name of automation
    */
    string name;

    /**
        Whether the automation is enabled
    */
    bool enabled = true;

    /**
        Type ID of the automation
    */
    string typeId;

    /**
        Instantiates a new Automation
    */
    this(Puppet parent) {
        this.parent = parent;
    }

    /**
        Adds a binding
    */
    void bind(AutomationBinding binding) {
        this.bindings ~= binding;
    }


    void reconstruct(Puppet puppet) {
        foreach(ref binding; bindings.dup) {
            binding.reconstruct(parent);
        }
    }

    /**
        Finalizes the loading of the automation
    */
    final void finalize(Puppet parent) {
        this.parent = parent;
        foreach(ref binding; bindings) {
            binding.finalize(parent);
        }
    }

    /**
        Updates and applies the automation to all the parameters
        that this automation is bound to
    */
    final void update() {
        if (!enabled) return;
        this.onUpdate();
    }

    /**
        Serializes a parameter
    */
    void onSerialize(ref JSONValue object) {
        object["type"] = typeId;
        object["name"] = name;
        object["bindings"] = bindings.serialize();
    }

    /**
        Deserializes a parameter
    */
    void onDeserialize(ref JSONValue object) {
        object.tryGetRef(typeId, "type");
        object.tryGetRef(name, "name");
        object.tryGetRef(bindings, "bindings");

        this.deserializeSelf(object);
    }
}

//
//  SERIALIZATION SHENNANIGANS
//

private {
    Automation delegate(Puppet parent)[string] typeFactories;
}

void inRegisterAutomationType(T)() if (is(T : Automation)) {
    import std.traits : getUDAs;
    typeFactories[getUDAs!(T, TypeId)[0].id] = (Puppet parent) {
        return new T(parent);
    };
}

/**
    Instantiates automation
*/
Automation inInstantiateAutomation(string id, Puppet parent) {
    return typeFactories[id](parent);
}

/**
    Gets whether a node type is present in the factories
*/
bool inHasAutomationType(string id) {
    return (id in typeFactories) !is null;
}

mixin template InAutomation(T) {
    static this() {
        inRegisterAutomationType!(T);
    }
}