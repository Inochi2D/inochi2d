/*
    Inochi2D Simple Physics Node

    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Asahi Lina
*/
module inochi2d.core.nodes.drivers.simplephysics;
import inochi2d.core.nodes.drivers;
import inochi2d.core.nodes.common;
import inochi2d.core.nodes;
import inochi2d.fmt;
import inochi2d.core.dbg;
import inochi2d.core;
import inochi2d.math;
import inochi2d.phys;
import inochi2d;
import std.exception;
import std.algorithm.sorting;
import std.stdio;

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
}

class Pendulum : PhysicsSystem {
    SimplePhysics driver;

private:
    vec2 bob = vec2(0, 0);
    float angle = 0;
    float dAngle = 0;

protected:
    override
    void eval(float t) {
        setD(angle, dAngle);
        float lengthRatio = driver.getGravity() / driver.length;
        float critDamp = 2 * sqrt(lengthRatio);
        float dd = -lengthRatio * sin(angle);
        dd -= dAngle * driver.angleDamping * critDamp;
        setD(dAngle, dd);
    }

public:

    this(SimplePhysics driver) {
        this.driver = driver;

        bob = driver.anchor + vec2(0, driver.length);

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
        bob = driver.anchor + dBob * driver.length;

        driver.output = bob;
    }

    override
    void drawDebug(mat4 trans = mat4.identity) {
        vec3[] points = [
            vec3(driver.anchor.x, driver.anchor.y, 0),
            vec3(bob.x, bob.y, 0),
        ];

        inDbgSetBuffer(points);
        inDbgLineWidth(3);
        inDbgDrawLines(vec4(1, 0, 1, 1), trans);
    }

    override
    void updateAnchor() {
        bob = driver.anchor + vec2(0, driver.length);
    }
}

class SpringPendulum : PhysicsSystem {
    SimplePhysics driver;

private:
    vec2 bob = vec2(0, 0);
    vec2 dBob = vec2(0, 0);

protected:
    override
    void eval(float t) {
        setD(bob, dBob);

        // These are normalized vs. mass
        float springKsqrt = driver.frequency * 2 * PI;
        float springK = springKsqrt ^^ 2;

        float g = driver.getGravity();
        float restLength = driver.length - g / springK;

        vec2 offPos = bob - driver.anchor;
        vec2 offPosNorm = offPos.normalized;

        float lengthRatio = driver.getGravity() / driver.length;
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
            dBobRot.x * driver.angleDamping * critDampAngle,
            dBobRot.y * driver.lengthDamping * critDampLength,
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

        bob = driver.anchor + vec2(0, driver.length);

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
    void drawDebug(mat4 trans = mat4.identity) {
        vec3[] points = [
            vec3(driver.anchor.x, driver.anchor.y, 0),
            vec3(bob.x, bob.y, 0),
        ];

        inDbgSetBuffer(points);
        inDbgLineWidth(3);
        inDbgDrawLines(vec4(1, 0, 1, 1), trans);
    }

    override
    void updateAnchor() {
        bob = driver.anchor + vec2(0, driver.length);
    }
}

/**
    Simple Physics Node
*/
@TypeId("SimplePhysics")
class SimplePhysics : Driver {
private:
    this() { }

    @Name("param")
    uint paramRef = InInvalidUUID;

    @Ignore
    Parameter param_;

protected:
    override
    string typeId() { return "SimplePhysics"; }

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void serializeSelf(ref InochiSerializer serializer) {
        super.serializeSelf(serializer);
        serializer.putKey("param");
        serializer.serializeValue(paramRef);
        serializer.putKey("model_type");
        serializer.serializeValue(modelType_);
        serializer.putKey("map_mode");
        serializer.serializeValue(mapMode);
        serializer.putKey("gravity");
        serializer.serializeValue(gravity);
        serializer.putKey("length");
        serializer.serializeValue(length);
        serializer.putKey("frequency");
        serializer.serializeValue(frequency);
        serializer.putKey("angle_damping");
        serializer.serializeValue(angleDamping);
        serializer.putKey("length_damping");
        serializer.serializeValue(lengthDamping);
        serializer.putKey("output_scale");
        outputScale.serialize(serializer);
    }

    override
    SerdeException deserializeFromFghj(Fghj data) {
        super.deserializeFromFghj(data);

        if (!data["param"].isEmpty)
            if (auto exc = data["param"].deserializeValue(this.paramRef)) return exc;
        if (!data["model_type"].isEmpty)
            if (auto exc = data["model_type"].deserializeValue(this.modelType_)) return exc;
        if (!data["map_mode"].isEmpty)
            if (auto exc = data["map_mode"].deserializeValue(this.mapMode)) return exc;
        if (!data["gravity"].isEmpty)
            if (auto exc = data["gravity"].deserializeValue(this.gravity)) return exc;
        if (!data["length"].isEmpty)
            if (auto exc = data["length"].deserializeValue(this.length)) return exc;
        if (!data["frequency"].isEmpty)
            if (auto exc = data["frequency"].deserializeValue(this.frequency)) return exc;
        if (!data["angle_damping"].isEmpty)
            if (auto exc = data["angle_damping"].deserializeValue(this.angleDamping)) return exc;
        if (!data["length_damping"].isEmpty)
            if (auto exc = data["length_damping"].deserializeValue(this.lengthDamping)) return exc;
        if (!data["output_scale"].isEmpty)
            if (auto exc = outputScale.deserialize(data["output_scale"])) return exc;

        return null;
    }

public:
    PhysicsModel modelType_ = PhysicsModel.Pendulum;
    ParamMapMode mapMode = ParamMapMode.AngleLength;

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
    vec2 outputScale = vec2(1, 1);

    @Ignore
    vec2 anchor = vec2(0, 0);

    @Ignore
    vec2 output;

    @Ignore
    PhysicsSystem system;

    /**
        Constructs a new SimplePhysics node
    */
    this(Node parent = null) {
        this(inCreateUUID(), parent);
    }

    /**
        Constructs a new SimplePhysics node
    */
    this(uint uuid, Node parent = null) {
        super(uuid, parent);
        reset();
    }

    override
    void beginUpdate() {
        super.beginUpdate();
    }

    override
    void update() {
        super.update();
    }

    override
    Parameter[] getAffectedParameters() {
        if (param_ is null) return [];
        return [param_];
    }

    override
    void updateDriver() {
        
        // Timestep is limited to 10 seconds, as if you
        // Are getting 0.1 FPS, you have bigger issues to deal with.
        float h = min(deltaTime(), 10);

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
        auto anchorPos = transform.matrix * vec4(0, 0, 0, 1);
        anchor = vec2(anchorPos.x, anchorPos.y);
    }

    void updateOutputs() {
        if (param is null) return;

        // Okay, so this is confusing. We want to translate the angle back to local space,
        // but not the coordinates.

        // Transform the physics output back into local space.
        // The origin here is the anchor. This gives us the local angle.
        auto localPos4 = transform.matrix.inverse * vec4(output.x, output.y, 0, 1);
        vec2 localAngle = vec2(localPos4.x, localPos4.y);
        localAngle.normalize();

        // Figure out the relative length. We can work this out directly in global space.
        auto relLength = output.distance(anchor) / length;

        vec2 paramVal;
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
            default: assert(0);
        }

        param.value = vec2(paramVal.x * outputScale.x, paramVal.y * outputScale.y);
        param.update();
    }

    override
    void reset() {
        updateInputs();

        switch (modelType) {
            case PhysicsModel.Pendulum:
                system = new Pendulum(this);
                break;
            case PhysicsModel.SpringPendulum:
                system = new SpringPendulum(this);
                break;
            default:
                assert(0);
        }
    }

    override
    void finalize() {
        param_ = puppet.findParameter(paramRef);
        super.finalize();
        reset();
    }

    override
    void drawDebug() {
        system.drawDebug();
    }

    Parameter param() {
        return param_;
    }

    void param(Parameter p) {
        param_ = p;
        if (p is null) paramRef = InInvalidUUID;
        else paramRef = p.uuid;
    }

    float getScale() {
        return puppet.physics.pixelsPerMeter;
    }

    float getGravity() {
        return gravity * puppet.physics.gravity * getScale();
    }

    PhysicsModel modelType() {
        return modelType_;
    }

    void modelType(PhysicsModel t) {
        modelType_ = t;
        reset();
    }
}

mixin InNode!SimplePhysics;