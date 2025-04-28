/*
    Inochi2D Simple Physics Node

    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Asahi Lina
*/
module inochi2d.core.nodes.drivers.simplephysics;
private {
import inochi2d.core.nodes.drivers;
import inochi2d.core.nodes.common;
//import inochi2d.core.nodes;
import inochi2d.fmt;
import inochi2d.core.dbg;
//import inochi2d.core;
import inochi2d.core.math;
import inochi2d.phys;
import inochi2d;
import std.exception;
import std.algorithm.sorting;
import std.stdio;
}

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
    SimplePhysics driver;

private:
    vec2 bob = vec2(0, 0);
    float angle = 0;
    float dAngle = 0;

protected:
    override
    void eval(float t) {
        setD(angle, dAngle);
        float lengthRatio = driver.getGravity() / driver.getLength();
        float critDamp = 2 * sqrt(lengthRatio);
        float dd = -lengthRatio * sin(angle);
        dd -= dAngle * driver.getAngleDamping() * critDamp;
        setD(dAngle, dd);
    }

public:

    this(SimplePhysics driver) {
        this.driver = driver;

        bob = driver.anchor + vec2(0, driver.getLength());

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
        bob = driver.anchor + dBob * driver.getLength();

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
        bob = driver.anchor + vec2(0, driver.getLength());
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
        float springKsqrt = driver.getFrequency() * 2 * PI;
        float springK = springKsqrt ^^ 2;

        float g = driver.getGravity();
        float restLength = driver.getLength() - g / springK;

        vec2 offPos = bob - driver.anchor;
        vec2 offPosNorm = offPos.normalized;

        float lengthRatio = driver.getGravity() / driver.getLength();
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
            dBobRot.x * driver.getAngleDamping() * critDampAngle,
            dBobRot.y * driver.getLengthDamping() * critDampLength,
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

        bob = driver.anchor + vec2(0, driver.getLength());

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
        bob = driver.anchor + vec2(0, driver.getLength());
    }
}

/**
    Simple Physics Node
*/
@TypeId("SimplePhysics")
class SimplePhysics : Driver {
private:
    this() { }

    uint paramRef = InInvalidUUID;

    Parameter param_;

    float offsetGravity = 1.0;

    float offsetLength = 0;

    float offsetFrequency = 1;

    float offsetAngleDamping = 0.5;

    float offsetLengthDamping = 0.5;

    vec2 offsetOutputScale = vec2(1, 1);

protected:
    override
    string typeId() { return "SimplePhysics"; }

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void serializeSelfImpl(ref JSONValue object, bool recursive=true) {
        super.serializeSelfImpl(object, recursive);
        object["param"] = paramRef;
        object["model_type"] = modelType_;
        object["map_mode"] = mapMode;
        object["gravity"] = gravity;
        object["length"] = length;
        object["frequency"] = frequency;
        object["angle_damping"] = angleDamping;
        object["length_damping"] = lengthDamping;
        object["output_scale"] = outputScale.serialize();
        object["local_only"] = localOnly;
    }

    override
    void onDeserialize(ref JSONValue object) {
        super.onDeserialize(object);
        object.tryGetRef(paramRef, "param");
        object.tryGetRef(modelType_, "model_type");
        object.tryGetRef(mapMode, "map_mode");
        object.tryGetRef(gravity, "gravity");
        object.tryGetRef(length, "length");
        object.tryGetRef(frequency, "frequency");
        object.tryGetRef(angleDamping, "angle_damping");
        object.tryGetRef(lengthDamping, "length_damping");
        object.tryGetRef(outputScale, "output_scale");
        object.tryGetRef(localOnly, "local_only");
    }

public:
    PhysicsModel modelType_ = PhysicsModel.Pendulum;
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
    vec2 outputScale = vec2(1, 1);

    vec2 prevAnchor = vec2(0, 0);
    mat4 prevTransMat;
    bool prevAnchorSet = false;

    vec2 anchor = vec2(0, 0);

    vec2 output;

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
        offsetGravity = 1;
        offsetLength = 0;
        offsetFrequency = 1;
        offsetAngleDamping = 1;
        offsetLengthDamping = 1;
        offsetOutputScale = vec2(1, 1);
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
        prevAnchorSet = false;
    }

    void updateAnchors() {
        system.updateAnchor();
    }

    void updateInputs() {
        if (prevAnchorSet) {
        } else {
            auto anchorPos = localOnly ? 
                (vec4(transformLocal.translation, 1)) : 
                (transform.matrix * vec4(0, 0, 0, 1));
            anchor = vec2(anchorPos.x, anchorPos.y);
        }
    }

    override
    void preProcess() {
        auto prevPos = (localOnly ? 
            (vec4(transformLocal.translation, 1)) : 
            (transform.matrix * vec4(0, 0, 0, 1))).xy;
        super.preProcess(); 
        auto anchorPos = (localOnly ? 
            (vec4(transformLocal.translation, 1)) : 
            (transform.matrix * vec4(0, 0, 0, 1))).xy;
        if (anchorPos != prevPos) {
            anchor = anchorPos;
            prevTransMat = transform.matrix.inverse;
            prevAnchorSet = true;
        }
    }

    override
    void postProcess() { 
        auto prevPos = (localOnly ? 
            (vec4(transformLocal.translation, 1)) : 
            (transform.matrix * vec4(0, 0, 0, 1))).xy;
        super.postProcess(); 
        auto anchorPos = (localOnly ? 
            (vec4(transformLocal.translation, 1)) : 
            (transform.matrix * vec4(0, 0, 0, 1))).xy;
        if (anchorPos != prevPos) {
            anchor = anchorPos;
            prevTransMat = transform.matrix.inverse;
            prevAnchorSet = true;
        }
    }

    void updateOutputs() {
        if (param is null) return;

        vec2 oscale = getOutputScale();

        // Okay, so this is confusing. We want to translate the angle back to local space,
        // but not the coordinates.

        // Transform the physics output back into local space.
        // The origin here is the anchor. This gives us the local angle.
        vec4 localPos4;
        localPos4 = localOnly ? 
        vec4(output.x, output.y, 0, 1) : 
        ((prevAnchorSet? prevTransMat: transform.matrix.inverse) * vec4(output.x, output.y, 0, 1));
        vec2 localAngle = vec2(localPos4.x, localPos4.y);
        localAngle.normalize();

        // Figure out the relative length. We can work this out directly in global space.
        auto relLength = output.distance(anchor) / getLength();

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
            default: assert(0);
        }

        param.pushIOffset(vec2(paramVal.x * oscale.x, paramVal.y * oscale.y), ParamMergeMode.forced);
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

    PhysicsModel modelType() {
        return modelType_;
    }

    void modelType(PhysicsModel t) {
        modelType_ = t;
        reset();
    }

       override
    bool hasParam(string key) {
        if (super.hasParam(key)) return true;

        switch(key) {
            case "gravity":
            case "length":
            case "frequency":
            case "angleDamping":
            case "lengthDamping":
            case "outputScale.x":
            case "outputScale.y":
                return true;
            default:
                return false;
        }
    }

    override
    float getDefaultValue(string key) {
        // Skip our list of our parent already handled it
        float def = super.getDefaultValue(key);
        if (def.isFinite) return def;

        switch(key) {
            case "gravity":
            case "frequency":
            case "angleDamping":
            case "lengthDamping":
            case "outputScale.x":
            case "outputScale.y":
                return 1;
            case "length":
                return 0;
            default: return float();
        }
    }

    override
    bool setValue(string key, float value) {
        
        // Skip our list of our parent already handled it
        if (super.setValue(key, value)) return true;

        switch(key) {
            case "gravity":
                offsetGravity *= value;
                return true;
            case "length":
                offsetLength += value;
                return true;
            case "frequency":
                offsetFrequency *= value;
                return true;
            case "angleDamping":
                offsetAngleDamping *= value;
                return true;
            case "lengthDamping":
                offsetLengthDamping *= value;
                return true;
            case "outputScale.x":
                offsetOutputScale.x *= value;
                return true;
            case "outputScale.y":
                offsetOutputScale.y *= value;
                return true;
            default: return false;
        }
    }
    
    override
    float getValue(string key) {
        switch(key) {
            case "gravity":         return offsetGravity;
            case "length":          return offsetLength;
            case "frequency":       return offsetFrequency;
            case "angleDamping":    return offsetAngleDamping;
            case "lengthDamping":   return offsetLengthDamping;
            case "outputScale.x":   return offsetOutputScale.x;
            case "outputScale.y":   return offsetOutputScale.y;
            default:                return super.getValue(key);
        }
    }

    /// Gets the final gravity
    float getGravity() { return (gravity * offsetGravity) * puppet.physics.gravity * getScale(); }

    /// Gets the final length
    float getLength() { return length + offsetLength; }

    /// Gets the final frequency
    float getFrequency() { return frequency * offsetFrequency; }

    /// Gets the final angle damping
    float getAngleDamping() { return angleDamping * offsetAngleDamping; }

    /// Gets the final length damping
    float getLengthDamping() { return lengthDamping * offsetLengthDamping; }

    /// Gets the final length damping
    vec2 getOutputScale() { return outputScale * offsetOutputScale; }
}

mixin InNode!SimplePhysics;