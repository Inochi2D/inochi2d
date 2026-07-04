/**
    1D Parameter

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)

    Authors:
        Luna Nielsen
        Mireille Arseneault
        Hoshino Lina
*/
module inochi2d.param.parameters.param1d;
import inochi2d.param.parameter;
import inochi2d.core.registry;
import inochi2d.core.serde;
import inochi2d.core.math;
import inochi2d.core.guid;
import inochi2d.common;
import inochi2d.puppet;
import nulib;
import numem;

/**
    1D variant of a parameter.
*/
@TypeId("1d", IN_MAKE_TAG!(1, 0))
class Parameter1D : Parameter {
protected:
@nogc:

    /**
        Serialize this parameter.
    */
    override
    void onSerialize(ref DataNode object) {
        super.onSerialize(object);
        object["min"] = min.serialize();
        object["max"] = max.serialize();
        object["defaults"] = defaults.serialize();
        object["points"] = points.serialize();
    }

    /**
        Deserialize this parameter.
    */
    override
    void onDeserialize(ref DataNode object, ref ModelState state) {
        super.onDeserialize(object, state);
        object.tryGetRef(state, min, "min");
        object.tryGetRef(state, max, "max");
        object.tryGetRef(state, defaults, "defaults");


        // 0.8->0.9 upgrades
        if (state.doUpgrade08) {
            state.info("0.8->0.9: Upgrading 1D axis mapping...");
            object.tryGetRef(state, points, "axis_points");
            return;
        }

        object.tryGetRef(state, points, "points");
    }

    /**
        Finalizes the parameter.

        Params:
            puppet =    The parent puppet
            state =     The state of the deserializer.
    */
    override
    void onFinalize(Puppet puppet, ref ModelState state) {
        super.onFinalize(puppet, state);
        value = defaults;
    }

public:

    /**
        The current value of this parameter.
    */
    float value = 0;

    /**
        The previous value of this parameter.
    */
    float prev = 0;

    /**
        The default value of this parameter.
    */
    float defaults = 0;

    /**
        The lower bound of this parameter.
    */
    float min = 0;

    /**
        The upper bound of this parameter.
    */
    float max = 1;

    /**
        Our keypoints' positions.
    */
    vector!float points;

    /**
        The lower bound of this parameter.
    */
    override @property float[] lowerBound() @trusted => (&min)[0..1];

    /**
        The upper bound of this parameter.
    */
    override @property float[] upperBound() @trusted => (&max)[0..1];

    /**
        The current value of the parameter.
    */
    override @property float[] currentValue() @trusted => (&value)[0..1];

    /**
        The dimensionality of the parameter.
    */
    override @property int dimensions() => 1;

    /**
        Counts of elements in each axis.
    */
    override @property uint[] elementCounts() {
        static uint[1] counts;
        counts = [cast(uint)points.length];
        return counts[0..1];
    }

    /**
        Construct a new named parameter.
    */
    this(string name = null) {
        float[2] points_init = [0, 1];
        points = points_init;
        guid = inNewGUID();
        this.name = name;
    }

    /**
        Force this parameter to take on the given value.

        Params:
            value = The new value this parameter will take on.
    */
    void pushValue(float value) {
        this.value = value;
    }

    /**
        Find the keypoint index of the given position, as well as its normal.

        Params:
            pos = A position along our keypoints. Must be within min & max.
            norm = The given position, normalized within its keypoint.

        Returns:
            The index of the keypoint the given position falls on.
    */
    ptrdiff_t findKeypointAndNormal(float pos, out float norm) {
        return searchPoints(points, pos, norm);
    }

    /**
        Normalize the given position between min & max.
    */
    float normalize(float pos) const {
        return (pos - min) / (max - min);
    }

    /**
        Linearly interpolate from min to max by the given value.
    */
    float lerp(float norm) const {
        return .lerp(min, max, norm);
    }

    /**
        Update our bindings with the value of this parameter.
    */
    override
    void update() {
        if (!active)
            return;

        float norm;
        ptrdiff_t index = findKeypointAndNormal(value, norm);
        if (index >= 0) {
            foreach (binding; bindings) {
                binding.apply(vec2u(index, 0), vec2(norm, 0));
            }
        }
    }
}
mixin Register!(Parameter1D, in_param_registry);