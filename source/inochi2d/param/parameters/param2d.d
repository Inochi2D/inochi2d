/**
    2D Parameter

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)

    Authors:
        Luna Nielsen
        Mireille Arseneault
        Hoshino Lina
*/
module inochi2d.param.parameters.param2d;
import inochi2d.param.parameters;
import inochi2d.param.utils;
import inochi2d.core.registry;
import inochi2d.core.serde;
import inochi2d.core.math;
import inochi2d.core.guid;
import inochi2d.common;
import inochi2d.puppet;
import nulib;
import numem;

/**
    2D variant of a parameter.
*/
@TypeId("2d", IN_MAKE_TAG!(2, 0))
class Parameter2D : Parameter {
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
        object["hpoints"] = hpoints.serialize();
        object["vpoints"] = vpoints.serialize();
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
            state.info("0.8->0.9: Upgrading 2D axis mapping...");

            auto axes = "axis_points" in object;
            if (axes && (*axes).isArray) {
                (*axes).tryGetRef(state, hpoints, 0);
                (*axes).tryGetRef(state, vpoints, 1);
            }
            return;
        }

        object.tryGetRef(state, hpoints, "hpoints");
        object.tryGetRef(state, vpoints, "vpoints");
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
    vec2 value = vec2(0, 0);

    /**
        The previous value of this parameter.
    */
    vec2 prev = vec2(0, 0);

    /**
        The default value of this parameter.
    */
    vec2 defaults = vec2(0, 0);

    /**
        The lower bounds of this parameter.
    */
    vec2 min = vec2(0, 0);

    /**
        The upper bounds of this parameter.
    */
    vec2 max = vec2(1, 1);

    /**
        Our horizontal keypoints' positions.
    */
    vector!float hpoints;

    /**
        Our vertical keypoints' positions.
    */
    vector!float vpoints;

    /**
        The dimensionality of the parameter.
    */
    override @property int dimensions() => 2;

    /**
        The current value of the parameter.
    */
    override @property float[] currentValue() @trusted => value.data[];

    /**
        The lower bound of this parameter.
    */
    override @property float[] lowerBound() => min.data[];

    /**
        The upper bound of this parameter.
    */
    override @property float[] upperBound() => max.data[];

    /**
        Counts of elements in each axis.
    */
    override @property uint[] elementCounts() {
        static uint[2] counts;
        counts = [cast(uint)hpoints.length, cast(uint)vpoints.length];
        return counts[0..2];
    }

    /**
        Construct a new named parameter.
    */
    this(string name = null) {
        float[2] points_init = [0, 1];
        hpoints = points_init;
        vpoints = points_init;
        guid = inNewGUID();
        this.name = name;
    }

    /**
        Update our bindings with the value of this parameter.
    */
    override
    void update() {
        if (!active)
            return;

        vec2 norm;
        vec2u index = findKeypointAndNormal(value, norm);

        foreach (binding; bindings) {
            binding.apply(index, norm);
        }
    }

    /**
        Force this parameter to take on the given value.

        Params:
            value = The new value this parameter will take on.
    */
    void pushValue(vec2 value) {
        this.value = value;
    }

    /**
        Force this parameter to take on the given value.

        Params:
            axis  = The axis along which the value is set.
            value = The new value this parameter will take on.
    */
    void pushValue(ParameterAxis axis, float value) {
        final switch (axis) {
            case ParameterAxis.rows:
                this.value.y = value;
                break;

            case ParameterAxis.columns:
                this.value.x = value;
                break;
        }
    }

    /**
        Find the keypoint index of the given position, as well as its normal.

        Params:
            pos = A position along our keypoints. Must be within min & max.
            norm = The given position, normalized within its keypoint.

        Returns:
            The index of the keypoint the given position falls on.
    */
    vec2i findKeypointAndNormal(vec2 pos, out vec2 norm) {
        assert(pos.x >= min.x && pos.x <= max.x);
        assert(pos.y >= min.y && pos.y <= max.y);
        const x = searchPoints(hpoints, pos.x, norm.x);
        const y = searchPoints(vpoints, pos.y, norm.y);
        return vec2i(x, y);
    }

    /**
        Normalize the given position memberwise between min & max.
    */
    vec2 normalize(vec2 pos) const {
        const x = (pos.x - min.x) / (max.x - min.x);
        const y = (pos.y - min.y) / (max.y - min.y);
        return vec2(x, y);
    }

    /**
        Linearly interpolate min & max by the given value.
    */
    vec2 lerp(vec2 norm) const {
        const x = .lerp(min.x, max.x, norm.x);
        const y = .lerp(min.y, max.y, norm.y);
        return vec2(x, y);
    }
}
mixin Register!(Parameter2D, in_param_registry);