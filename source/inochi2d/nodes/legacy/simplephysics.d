/**
    Inochi2D Simple Physics Node

    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Hoshino Lina
*/
module inochi2d.nodes.legacy.simplephysics;
import inochi2d.core.serde;
import inochi2d.core.guid;
import inochi2d.core.math;
import inochi2d.core.phys;
import inochi2d;
import numem;

// Allow disabling legacy node.
version (IN_NO_LEGACY) {
} else:

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
@TypeId("SimplePhysics", 0x00000103)
class SimplePhysics : Node {
private:
@nogc:
    float offsetGravity = 1.0;
    float offsetLength = 0;
    float offsetFrequency = 1;
    float offsetAngleDamping = 0.5;
    float offsetLengthDamping = 0.5;
    vec2 offsetOutputScale = vec2(1, 1);

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
            recursive = Whether to recurse through children.
    */
    override
    void onSerialize(ref DataNode object, bool recursive = true) {
        super.onSerialize(object, recursive);

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
            object = The DataNode to deserialize from.
    */
    override
    void onDeserialize(ref DataNode object) {
        super.onDeserialize(object);

        this.paramRef = object.tryGetGUID("param", "target");
        object.tryGetRef(modelType_, "model_type", PhysicsModel.Pendulum);
        object.tryGetRef(mapMode, "map_mode", ParamMapMode.AngleLength);
        object.tryGetRef(gravity, "gravity", 1.0);
        object.tryGetRef(length, "length", 100);
        object.tryGetRef(frequency, "frequency", 1.0);
        object.tryGetRef(angleDamping, "angle_damping", 0.5);
        object.tryGetRef(lengthDamping, "length_damping", 0.5);
        object.tryGetRef(outputScale, "output_scale", vec2(1, 1));
        object.tryGetRef(localOnly, "local_only", false);
    }

    /**
        Called when the node is to finalize its deserialization from disk.
    */
    override
    void onFinalize() {
        this.param_ = puppet.findParameter(paramRef);
        this.reset();
        super.onFinalize();
    }

    /**
        Called during the early update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onPreUpdate(DrawList drawList) {
        super.onPreUpdate(drawList);
        offsetGravity = 1;
        offsetLength = 0;
        offsetFrequency = 1;
        offsetAngleDamping = 1;
        offsetLengthDamping = 1;
        offsetOutputScale = vec2(1, 1);
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
    @property float finalGravity() @nogc => (gravity * offsetGravity) * puppet.properties.physicsGravity * this.scale;

    /**
        The final length
    */
    @property float finalLength() @nogc => length + offsetLength;

    /**
        The final frequency
    */
    @property float finalFrequency() @nogc => frequency * offsetFrequency;

    /**
        The final angle damping
    */
    @property float finalAngleDamping() @nogc => angleDamping * offsetAngleDamping;

    /**
        The final length damping
    */
    @property float finalLengthDamping() @nogc => lengthDamping * offsetLengthDamping;

    /**
        The final output scale
    */
    @property vec2 finalOutputScale() @nogc => outputScale * offsetOutputScale;

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
            (vec4(localTransform.translation, 1)) : (transform.matrix * vec4(0, 0, 0, 1));
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
            vec4(output.x, output.y, 0, 1) : (transform.matrix.inverse * vec4(output.x, output.y, 0, 1));
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
            param1d.updateBindings();
        } else if (auto param2d = cast(Parameter2D)param) {
            auto value = vec2(paramVal.x * oscale.x, paramVal.y * oscale.y);
            param2d.pushValue(value);
            param2d.updateBindings();
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

    /**
        Gets whether a property with the given name exists
        in the object.

        Params:
            key = The name of the property.
        
        Returns:
            $(D true) if the property exists,
            $(D false) otherwise.
    */
    override
    bool hasProperty(string key) const {
        switch (key) {
        case "gravity":
        case "length":
        case "frequency":
        case "angleDamping":
        case "lengthDamping":
        case "outputScale.x":
        case "outputScale.y":
            return true;
        default:
            return super.hasProperty(key);
        }
    }

    /**
        Gets the value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The floating point value of the property.
    */
    override
    float getProperty(string key) const {
        switch (key) {
        case "gravity":
            return offsetGravity;
        case "length":
            return offsetLength;
        case "frequency":
            return offsetFrequency;
        case "angleDamping":
            return offsetAngleDamping;
        case "lengthDamping":
            return offsetLengthDamping;
        case "outputScale.x":
            return offsetOutputScale.x;
        case "outputScale.y":
            return offsetOutputScale.y;
        default:
            return super.getProperty(key);
        }
    }

    /**
        Gets the default value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The default value of the property.
    */
    override
    float getPropertyDefault(string key) const {
        switch (key) {
        case "gravity":
        case "frequency":
        case "angleDamping":
        case "lengthDamping":
        case "outputScale.x":
        case "outputScale.y":
            return 1;
        case "length":
            return 0;
        default:
            return super.getPropertyDefault(key);
        }
    }

    /**
        Sets the value of the property.

        Params:
            key =   The name of the property.
            value = The value to set the property to.
    */
    override
    void setProperty(string key, float value) {
        switch (key) {
        case "gravity":
            offsetGravity *= value;
            return;
        case "length":
            offsetLength += value;
            return;
        case "frequency":
            offsetFrequency *= value;
            return;
        case "angleDamping":
            offsetAngleDamping *= value;
            return;
        case "lengthDamping":
            offsetLengthDamping *= value;
            return;
        case "outputScale.x":
            offsetOutputScale.x *= value;
            return;
        case "outputScale.y":
            offsetOutputScale.y *= value;
            return;
        default:
            return super.setProperty(key, value);
        }
    }
}

mixin Register!(SimplePhysics, in_node_registry);
