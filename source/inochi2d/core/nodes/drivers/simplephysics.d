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
        float dd = -(driver.getGravity() / driver.length) * sin(angle);
        dd -= dAngle * driver.angleDamping;
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

        //writefln("pos %s -> %s", driver.anchor, bob);

        inDbgSetBuffer(points);
        inDbgLineWidth(3);
        inDbgDrawLines(vec4(1, 0, 1, 1), trans);
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
        serializer.serializeValue(modelType);
        serializer.putKey("map_mode");
        serializer.serializeValue(mapMode);
        serializer.putKey("gravity");
        serializer.serializeValue(gravity);
        serializer.putKey("length");
        serializer.serializeValue(length);
        serializer.putKey("mass");
        serializer.serializeValue(mass);
        serializer.putKey("angle_damping");
        serializer.serializeValue(angleDamping);
        serializer.putKey("length_damping");
        serializer.serializeValue(lengthDamping);
    }

    /**
        Allows serializing self data (with compact serializer)
    */
    override
    void serializeSelf(ref InochiSerializerCompact serializer) {
        super.serializeSelf(serializer);
        serializer.putKey("param");
        serializer.serializeValue(paramRef);
        serializer.putKey("model_type");
        serializer.serializeValue(modelType);
        serializer.putKey("map_mode");
        serializer.serializeValue(mapMode);
        serializer.putKey("gravity");
        serializer.serializeValue(gravity);
        serializer.putKey("length");
        serializer.serializeValue(length);
        serializer.putKey("mass");
        serializer.serializeValue(mass);
        serializer.putKey("angle_damping");
        serializer.serializeValue(angleDamping);
        serializer.putKey("length_damping");
        serializer.serializeValue(lengthDamping);
    }

    override
    SerdeException deserializeFromFghj(Fghj data) {
        super.deserializeFromFghj(data);

        if (!data["param"].isEmpty)
            if (auto exc = data["param"].deserializeValue(this.paramRef)) return exc;
        if (!data["model_type"].isEmpty)
            if (auto exc = data["model_type"].deserializeValue(this.modelType)) return exc;
        if (!data["map_mode"].isEmpty)
            if (auto exc = data["map_mode"].deserializeValue(this.mapMode)) return exc;
        if (!data["gravity"].isEmpty)
            if (auto exc = data["gravity"].deserializeValue(this.gravity)) return exc;
        if (!data["length"].isEmpty)
            if (auto exc = data["length"].deserializeValue(this.length)) return exc;
        if (!data["mass"].isEmpty)
            if (auto exc = data["mass"].deserializeValue(this.mass)) return exc;
        if (!data["angle_damping"].isEmpty)
            if (auto exc = data["angle_damping"].deserializeValue(this.angleDamping)) return exc;
        if (!data["length_damping"].isEmpty)
            if (auto exc = data["length_damping"].deserializeValue(this.lengthDamping)) return exc;

        return null;
    }

public:
    PhysicsModel modelType = PhysicsModel.Pendulum;
    ParamMapMode mapMode = ParamMapMode.AngleLength;

    float gravity = 1.0;
    float length = 100;
    float mass = 1;
    float angleDamping = 10;
    float lengthDamping = 0.5;

    @Ignore
    vec2 anchor = vec2(0, 0);

    @Ignore
    vec2 rest;

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
        float h = deltaTime();

        updateInputs();
        system.tick(h);
        updateOutputs();
    };

    void updateInputs() {
        auto anchorPos = transform.matrix * vec4(0, 0, 0, 1);
        anchor = vec2(anchorPos.x, anchorPos.y);
        auto restPos = transform.matrix * vec4(0, length, 0, 1);
        rest = vec2(restPos.x, restPos.y);
    }

    void updateOutputs() {
        if (param is null) return;

        auto localPos4 = transform.matrix.inverse * vec4(output.x, output.y, 0, 1);
        vec2 localPos = vec2(localPos4.x, localPos4.y);
        vec2 localPosNorm = localPos / length;

        vec2 paramVal;
        switch (mapMode) {
            case ParamMapMode.XY:
                paramVal = localPosNorm - vec2(0, 1);
                break;
            case ParamMapMode.AngleLength:
                float a = atan2(-localPosNorm.x, localPosNorm.y) / PI;
                float d = localPosNorm.distance(vec2(0, 0));
                paramVal = vec2(a, d);
                break;
            default: assert(0);
        }

        param.value = paramVal;
        param.update();
    }

    override
    void reset() {
        updateInputs();

        switch (modelType) {
            case PhysicsModel.Pendulum:
                system = new Pendulum(this);
                break;
            default:
                assert(0);
        }
    }

    override
    void finalize() {
        param_ = puppet.findParameter(paramRef);
        debug writefln("paramRef %d", paramRef);
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
        debug writefln("paramRef %d", paramRef);
    }

    float getGravity() {
        return gravity * 52714;
    }
}

mixin InNode!SimplePhysics;