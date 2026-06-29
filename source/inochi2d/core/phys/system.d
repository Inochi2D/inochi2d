/**
    Inochi2D Physics Subsystem

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Hoshino Lina
*/
module inochi2d.core.phys.system;
import inochi2d;
import numath;
import numem;
import nulib;

abstract
class PhysicsSystem : NuObject {
private:
@nogc:
    map!(float*, size_t) variableMap;
    vector!(float*) refs;

    // Derivatives
    float[] kstate;
    float[] k0;
    float[] k1;
    float[] k2;
    float[] k3;
    float[] k4;

    float t;

    /// Helper that resizes all of the temporary arrays.
    void resize(size_t length) {
        kstate = kstate.nu_resize(length);
        k0 = k0.nu_resize(length);
        k1 = k1.nu_resize(length);
        k2 = k2.nu_resize(length);
        k3 = k3.nu_resize(length);
        k4 = k4.nu_resize(length);
    }

protected:
    /**
        Add a float variable to the simulation
    */
    size_t addVariable(float* var) {
        size_t index = refs.length;

        variableMap[var] = index;
        refs ~= var;

        this.resize(refs.length);
        return index;
    }

    /**
        Add a vec2 variable to the simulation
    */
    size_t addVariable(vec2* var) {
        size_t index = addVariable(&var.data[0]);
        addVariable(&var.data[1]);
        return index;
    }

    /**
        Set the derivative of a variable (solver input) by index
    */
    void setD(size_t index, float value) {
        k0[index] = value;
    }

    /**
        Set the derivative of a float variable (solver input)
    */
    void setD(ref float var, float value) {
        setD(variableMap[&var], value);
    }

    /**
        Set the derivative of a vec2 variable (solver input)
    */
    void setD(ref vec2 var, vec2 value) {
        setD(var.data[0], value.x);
        setD(var.data[1], value.y);
    }

    float[] getState() {
        foreach (idx, ptr; refs)
            kstate[idx] = *ptr;
        return kstate;
    }

    void setState(float[] vals) {
        foreach (idx, ptr; refs) {
            *ptr = vals[idx];
        }
    }

    /**
        Evaluate the simulation at a given time
    */
    abstract void eval(float t);

public:

     ~this() {
        variableMap.clear();
        refs.clear();

        // Free derivatives.
        nu_freea(kstate);
        nu_freea(k0);
        nu_freea(k1);
        nu_freea(k2);
        nu_freea(k3);
        nu_freea(k4);
    }

    /**
        Run a simulation tick (Runge-Kutta method)
    */
    void tick(float h) {
        float[] cur = getState();
        k0[0 .. $] = 0;

        eval(t);
        k1[0 .. $] = k0[0 .. $];

        foreach (i; 0 .. cur.length)
            *refs[i] = cur[i] + h * k1[i] / 2f;
        eval(t + h / 2f);
        k2[0 .. $] = k0[0 .. $];

        foreach (i; 0 .. cur.length)
            *refs[i] = cur[i] + h * k2[i] / 2f;
        eval(t + h / 2f);
        k3[0 .. $] = k0[0 .. $];

        foreach (i; 0 .. cur.length)
            *refs[i] = cur[i] + h * k3[i];
        eval(t + h);
        k4[0 .. $] = k0[0 .. $];

        foreach (i; 0 .. cur.length) {
            *refs[i] = cur[i] + h * (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]) / 6f;
            if (!isFinite(*refs[i])) {
                // Simulation failed, revert
                foreach (j; 0 .. cur.length)
                    *refs[j] = cur[j];
                break;
            }
        }

        t += h;
    }

    /**
        Updates the anchor for the physics system
    */
    abstract void updateAnchor();
}
