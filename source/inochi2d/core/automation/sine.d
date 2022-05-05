/*
    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.automation.sine;
import inochi2d.core.automation;
import inochi2d;
import std.math;

enum SineType {
    Sin,
    Cos,
    Tan
}

@TypeId("sine")
class SineAutomation : Automation {
protected:
    override
    void onUpdate() {
        foreach(ref binding; bindings) {
            float wave;
            switch(sineType) {
                case SineType.Sin:
                    wave = this.remapRange((sin((currentTime()*speed)+phase)+1.0)/2f, binding.range);
                    break;
                case SineType.Cos:
                    wave = this.remapRange((cos((currentTime()*speed)+phase)+1.0)/2f, binding.range);
                    break;
                case SineType.Tan:
                    wave = this.remapRange((tan((currentTime()*speed)+phase)+1.0)/2f, binding.range);
                    break;
                default: assert(0);
            }

            binding.addAxisOffset(wave);
        }
    }

    override
    void serializeSelf(ref InochiSerializer serializer) {
        serializer.putKey("speed");
        serializer.putValue(speed);
        serializer.putKey("sine_type");
        serializer.putValue(cast(int)sineType);
    }

    override
    void serializeSelf(ref InochiSerializerCompact serializer) {
        serializer.putKey("speed");
        serializer.putValue(speed);
        serializer.putKey("sine_type");
        serializer.putValue(cast(int)sineType);
    }

    override
    void deserializeSelf(Fghj data) {
        data["speed"].deserializeValue(speed);
        data["sine_type"].deserializeValue(sineType);
    }
public:

    /**
        Speed of the wave
    */
    float speed = 1f;

    /**
        The phase of the wave
    */
    float phase = 0f;

    /**
        The type of wave
    */
    SineType sineType = SineType.Sin;

    this(Puppet parent) {
        this.typeId = "sine";
        super(parent);
    }
}

mixin InAutomation!SineAutomation;