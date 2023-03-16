/*
    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.automation;
import inochi2d.math.serialization;
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
    void serialize(S)(ref S serializer) {
        auto state = serializer.objectBegin;
            serializer.putKey("param");
            serializer.putValue(param.name);
            serializer.putKey("axis");
            serializer.putValue(axis);
            serializer.putKey("range");
            range.serialize(serializer);
        serializer.objectEnd(state);
    }

    /**
        Deserializes a parameter
    */
    SerdeException deserializeFromFghj(Fghj data) {
        data["param"].deserializeValue(this.paramId);
        data["axis"].deserializeValue(this.axis);
        this.range.deserialize(data["axis"]);
        return null;
    }

    void restructure(Puppet puppet) {
    }

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
    @Ignore
    Puppet parent;

protected:

    @Ignore
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

    void serializeSelf(ref InochiSerializer serializer) { }
    void deserializeSelf(Fghj data) { }

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


    void restructure(Puppet puppet) {
        foreach(ref binding; bindings.dup) {
            binding.restructure(parent);
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
    void serialize(S)(ref S serializer) {
        auto state = serializer.objectBegin;
            serializer.putKey("type");
            serializer.serializeValue(typeId);
            serializer.putKey("name");
            serializer.serializeValue(name);
            serializer.putKey("bindings");
            serializer.serializeValue(bindings);
            this.serializeSelf(serializer);
        serializer.objectEnd(state);
    }

    /**
        Deserializes a parameter
    */
    SerdeException deserializeFromFghj(Fghj data) {
        data["name"].deserializeValue(this.name);
        data["bindings"].deserializeValue(this.bindings);
        this.deserializeSelf(data);
        return null;
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