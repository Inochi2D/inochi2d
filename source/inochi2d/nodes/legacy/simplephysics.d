/**
    Inochi2D Simple Physics Node

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Hoshino Lina
*/
module inochi2d.nodes.legacy.simplephysics;
import inochi2d.core.serde;
import inochi2d.core.guid;
import inochi2d.core.math;
import inochi2d.core.phys;
import inochi2d.common;
import inochi2d;
import numem;

// dfmt off
// Allow disabling legacy node.
version (IN_NO_LEGACY) {} else:
// dfmt on

/**
    Physics model to use for simple physics
*/
enum PhysicsModel {
    /**
        Rigid pendulum
    */
    Pendulum = "pendulum",

    /**
        Springy pendulum
    */
    SpringPendulum = "spring_pendulum",
}

enum ParamMapMode {
    AngleLength = "angle_length",
    XY = "xy",
    LengthAngle = "length_angle",
    YX = "yx",
}

class Pendulum : PhysicsSystem {
private:
@nogc:
    SimplePhysics driver;
    vec2 bob = vec2(0, 0);
    float angle = 0;
    float dAngle = 0;

protected:
    override
    void eval(float t) {
        setD(angle, dAngle);
        float lengthRatio = driver.finalGravity / driver.finalLength;
        float critDamp = 2 * sqrt(lengthRatio);
        float dd = -lengthRatio * sin(angle);
        dd -= dAngle * driver.finalAngleDamping * critDamp;
        setD(dAngle, dd);
    }

public:

    this(SimplePhysics driver) {
        this.driver = driver;

        bob = driver.anchor + vec2(0, driver.finalLength);

        addVariable(&angle);
        addVariable(&dAngle);
    }

    override
    void tick(float h) {
        // Compute the angle against the updated anchor position
        vec2 dBob = bob - driver.anchor;
        angle = atan2(-dBob.x, dBob.y);

        // Run the pendulum simulation in terms of angle
        super.tick(h);

        // Update the bob position at the new angle
        dBob = vec2(-sin(angle), cos(angle));
        bob = driver.anchor + dBob * driver.finalLength;

        driver.output = bob;
    }

    override
    void updateAnchor() {
        bob = driver.anchor + vec2(0, driver.finalLength);
    }
}

class SpringPendulum : PhysicsSystem {
private:
@nogc:
    SimplePhysics driver;

    vec2 bob = vec2(0, 0);
    vec2 dBob = vec2(0, 0);

protected:

    override
    void eval(float t) {
        setD(bob, dBob);

        // These are normalized vs. mass
        float springKsqrt = driver.finalFrequency * 2 * PI;
        float springK = springKsqrt ^^ 2;

        float g = driver.finalGravity;
        float restLength = driver.finalLength - g / springK;

        vec2 offPos = bob - driver.anchor;
        vec2 offPosNorm = offPos.normalized;

        float lengthRatio = driver.finalGravity / driver.finalLength;
        float critDampAngle = 2 * sqrt(lengthRatio);
        float critDampLength = 2 * springKsqrt;

        float dist = abs(driver.anchor.distance(bob));
        vec2 force = vec2(0, g);
        force -= offPosNorm * (dist - restLength) * springK;
        vec2 ddBob = force;

        vec2 dBobRot = vec2(
                dBob.x * offPosNorm.y + dBob.y * offPosNorm.x,
                dBob.y * offPosNorm.y - dBob.x * offPosNorm.x,
        );

        vec2 ddBobRot = -vec2(
                dBobRot.x * driver.finalAngleDamping * critDampAngle,
                dBobRot.y * driver.finalLengthDamping * critDampLength,
        );

        vec2 ddBobDamping = vec2(
                ddBobRot.x * offPosNorm.y - dBobRot.y * offPosNorm.x,
                ddBobRot.y * offPosNorm.y + dBobRot.x * offPosNorm.x,
        );

        ddBob += ddBobDamping;

        setD(dBob, ddBob);
    }

public:

    this(SimplePhysics driver) {
        this.driver = driver;

        bob = driver.anchor + vec2(0, driver.finalLength);

        addVariable(&bob);
        addVariable(&dBob);
    }

    override
    void tick(float h) {
        // Run the spring pendulum simulation
        super.tick(h);

        driver.output = bob;
    }

    override
    void updateAnchor() {
        bob = driver.anchor + vec2(0, driver.finalLength);
    }
}

/**
    Simple Physics Node
*/
@TypeId("SimplePhysics", IN_MAKE_TAG!(0, 0xFF))
class SimplePhysics : Node {
private:
@nogc:
    GUID paramRef = GUID.nil;
    PhysicsModel modelType_ = PhysicsModel.Pendulum;
    Parameter param_;
    vec2 output;

protected:
    PhysicsSystem system;

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
    */
    override
    void onSerialize(ref DataNode object) {
        super.onSerialize(object);

        auto target = paramRef.toString();
        object["target"] = target[];
        object["model_type"] = cast(string)modelType_;
        object["map_mode"] = cast(string)mapMode;
        object["gravity"] = gravity;
        object["length"] = length;
        object["frequency"] = frequency;
        object["angle_damping"] = angleDamping;
        object["length_damping"] = lengthDamping;
        object["output_scale"] = outputScale.serialize();
        object["local_only"] = localOnly;
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object =    The DataNode to deserialize from.
            state =     The state of the deserializer.
    */
    override
    void onDeserialize(ref DataNode object, ref ModelState state) {
        super.onDeserialize(object, state);

        this.paramRef = object.tryGetGUID(state, "param", "target");
        object.tryGetRef(state, modelType_, "model_type", PhysicsModel.Pendulum);
        object.tryGetRef(state, mapMode, "map_mode", ParamMapMode.AngleLength);
        object.tryGetRef(state, gravity, "gravity", 1.0);
        object.tryGetRef(state, length, "length", 100);
        object.tryGetRef(state, frequency, "frequency", 1.0);
        object.tryGetRef(state, angleDamping, "angle_damping", 0.5);
        object.tryGetRef(state, lengthDamping, "length_damping", 0.5);
        object.tryGetRef(state, outputScale, "output_scale", vec2(1, 1));
        object.tryGetRef(state, localOnly, "local_only", false);
    }

    /**
        Called when the node is to finalize its deserialization from disk.

        Params:
            state =     The state of the deserializer.
    */
    override
    void onFinalize(ref ModelState state) {
        this.param_ = puppet.findParameter(paramRef);
        this.reset();
        super.onFinalize(state);
    }

    /**
        Called when the node is to define its properties.

        Call $(D propList.define) with a quark to do this.

        Params:
            propList = The property list to populate.
    */
    override void onDefineProperties(ref PropertyStore propList) {
        super.onDefineProperties(propList);

        propList.define!float(PROP_LENGTH, 0);
        propList.define!float(PROP_GRAVITY, 1);
        propList.define!float(PROP_FREQUENCY, 1);
        propList.define!float(PROP_ANGLE_DAMPING, 1);
        propList.define!float(PROP_LENGTH_DAMPING, 1);
        propList.define!float(PROP_LENGTH_DAMPING, 1);
        propList.define!float(PROP_OUTPUT_SCALE_X, 1);
        propList.define!float(PROP_OUTPUT_SCALE_Y, 1);

        // Define combined overlays.
        propList.defineOverlay!vec2(PROP_OUTPUT_SCALE_XY, propList.offsetOf(PROP_OUTPUT_SCALE_X));
    }

    /**
        Called during the early update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onPreUpdate(DrawList drawList) {
        super.onPreUpdate(drawList);
    }

public:

    /**
        The mapping between physics space and parameter space.
    */
    ParamMapMode mapMode = ParamMapMode.AngleLength;

    /**
        Whether physics system listens to local transform only.
    */
    bool localOnly = false;

    /**
        Gravity scale (1.0 = puppet gravity)
    */
    float gravity = 1.0;

    /**
        Pendulum/spring rest length (pixels)
    */
    float length = 100;

    /**
        Resonant frequency (Hz)
    */
    float frequency = 1;

    /**
        Angular damping ratio
    */
    float angleDamping = 0.5;

    /**
        Length damping ratio
    */
    float lengthDamping = 0.5;

    /**
        Output scale
    */
    vec2 outputScale = vec2(1, 1);

    /**
        Previous anchor
    */
    vec2 prevAnchor = vec2(0, 0);

    /**
        Current anchor
    */
    vec2 anchor = vec2(0, 0);

    /**
        The parameter that the physics system affects.
    */
    @property Parameter param() => param_;
    @property void param(Parameter p) {
        this.param_ = p;
        this.paramRef = param_ ? param_.guid : GUID.nil;
    }

    /**
        The physics model to apply.
    */
    @property PhysicsModel modelType() => modelType_;
    @property void modelType(PhysicsModel t) {
        modelType_ = t;
        reset();
    }

    /**
        The affected parameters of the driver.
    */
    @property Parameter[] affectedParameters() @nogc => (&param_)[0 .. 1];

    /**
        Physics scale.
    */
    @property float scale() @nogc => puppet.properties.physicsPixelsPerMeter;

    /**
        The final gravity
    */
    @property float finalGravity() @nogc => (gravity * props.get!float(PROP_GRAVITY)) * puppet.properties.physicsGravity * this
        .scale;

    /**
        The final length
    */
    @property float finalLength() @nogc => length + props.get!float(PROP_LENGTH);

    /**
        The final frequency
    */
    @property float finalFrequency() @nogc => frequency * props.get!float(PROP_FREQUENCY);

    /**
        The final angle damping
    */
    @property float finalAngleDamping() @nogc => angleDamping * props.get!float(PROP_ANGLE_DAMPING);

    /**
        The final length damping
    */
    @property float finalLengthDamping() @nogc => lengthDamping * props.get!float(PROP_LENGTH_DAMPING);

    /**
        The final output scale
    */
    @property vec2 finalOutputScale() @nogc => outputScale * props.get!vec2(PROP_OUTPUT_SCALE_XY);

    ~this() {
        nogc_delete(system);
    }

    /**
        Constructs a new SimplePhysics node
    */
    this(Node parent = null) {
        this(inNewGUID(), parent);
        this.reset();
    }

    /**
        Constructs a new SimplePhysics node
    */
    this(GUID guid, Node parent = null) {
        super(guid, parent);
        this.reset();
    }

    /**
        Gets whether the given parameter is affected by
        this driver.

        Params:
            param = The parameter to query.
        
        Returns:
            $(D true) if the parameter is affected by 
            the driver, $(D false) otherwise.
    */
    final
    bool affectsParameter(ref Parameter param) {
        foreach (ref Parameter p; this.affectedParameters) {
            if (p.guid == param.guid)
                return true;
        }
        return false;
    }

    void updateDriver(float delta) {

        // Timestep is limited to 10 seconds, as if you
        // Are getting 0.1 FPS, you have bigger issues to deal with.
        float h = min(delta, 10);

        updateInputs();

        // Minimum physics timestep: 0.01s
        while (h > 0.01) {
            system.tick(0.01);
            h -= 0.01;
        }

        system.tick(h);
        updateOutputs();
    }

    void updateAnchors() {
        system.updateAnchor();
    }

    void updateInputs() {
        auto anchorPos = localOnly ?
            (vec4(localTransform.translation, 1)) : (this.matrix * vec4(0, 0, 0, 1));
        anchor = vec2(anchorPos.x, anchorPos.y);
    }

    void updateOutputs() {
        if (param is null)
            return;

        vec2 oscale = this.finalOutputScale;

        // Okay, so this is confusing. We want to translate the angle back to local space,
        // but not the coordinates.

        // Transform the physics output back into local space.
        // The origin here is the anchor. This gives us the local angle.
        auto localPos4 = localOnly ?
            vec4(output.x, output.y, 0, 1) : (this.matrix.inverse * vec4(output.x, output.y, 0, 1));
        vec2 localAngle = vec2(localPos4.x, localPos4.y).normalized;

        // Figure out the relative length. We can work this out directly in global space.
        auto relLength = output.distance(anchor) / this.finalLength;

        vec2 paramVal = vec2.zero;
        switch (mapMode) {
        case ParamMapMode.XY:
            auto localPosNorm = localAngle * relLength;
            paramVal = localPosNorm - vec2(0, 1);
            paramVal.y = -paramVal.y; // Y goes up for params
            break;
        case ParamMapMode.AngleLength:
            float a = atan2(-localAngle.x, localAngle.y) / PI;
            paramVal = vec2(a, relLength);
            break;
        case ParamMapMode.YX:
            auto localPosNorm = localAngle * relLength;
            paramVal = localPosNorm - vec2(0, 1);
            paramVal.y = -paramVal.y; // Y goes up for params
            paramVal = vec2(paramVal.y, paramVal.x);
            break;
        case ParamMapMode.LengthAngle:
            float a = atan2(-localAngle.x, localAngle.y) / PI;
            paramVal = vec2(relLength, a);
            break;
        default:
            break;
        }

        if (auto param1d = cast(Parameter1D)param) {
            auto value = paramVal.x * oscale.x;
            param1d.pushValue(value);
            param1d.update();
        } else if (auto param2d = cast(Parameter2D)param) {
            auto value = vec2(paramVal.x * oscale.x, paramVal.y * oscale.y);
            param2d.pushValue(value);
            param2d.update();
        }
    }

    void reset() {
        updateInputs();

        switch (modelType) {
        case PhysicsModel.Pendulum:
            system = nogc_new!Pendulum(this);
            break;
        case PhysicsModel.SpringPendulum:
            system = nogc_new!SpringPendulum(this);
            break;
        default:
            break;
        }
    }
}

mixin Register!(SimplePhysics, in_node_registry);
// dfmt off




//
//          QUARKS
//

mixin RegisterQuarks!();

/**
    Gravity
*/
@propkey("gravity")
__gshared immutable(quark) PROP_GRAVITY;

/**
    Length
*/
@propkey("length")
__gshared immutable(quark) PROP_LENGTH;

/**
    Frequency
*/
@propkey("frequency")
__gshared immutable(quark) PROP_FREQUENCY;

/**
    Angle damping
*/
@propkey("angleDamping")
__gshared immutable(quark) PROP_ANGLE_DAMPING;

/**
    Length damping
*/
@propkey("lengthDamping")
__gshared immutable(quark) PROP_LENGTH_DAMPING;

/**
    Output scale xy
*/
@propkey("outputScale.xy")
__gshared immutable(quark) PROP_OUTPUT_SCALE_XY;

/**
    Output scale x
*/
@propkey("outputScale.x")
__gshared immutable(quark) PROP_OUTPUT_SCALE_X;

/**
    Output scale y
*/
@propkey("outputScale.y")
__gshared immutable(quark) PROP_OUTPUT_SCALE_Y;
