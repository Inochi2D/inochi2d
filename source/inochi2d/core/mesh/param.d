module inochi2d.core.mesh.param;
import inochi2d.math;

/**
    The type of a parameter
*/
enum ParamType : ubyte {
    X,
    XY
}

/**
    UDA: UDA for named Parameters
*/
struct Named { string name; }

/**
    A parameter
*/
struct Parameter {

    /**
        The type of the parameter
    */
    ParamType type;

    /**
        Constructs a parameter from value
    */
    this(float value) {
        this.value = value;
    }

    /**
        Constructs a parameter from value
    */
    this(vec2 value) {
        this.values = value;
    }

    /**
        Allow assigning float values directly
    */
    void opAssign(float value) {
        this.value = value;
    }

    /**
        Allow assigning vec2 values directly
    */
    void opAssign(vec2 value) {
        this.values = value;
    }


    union {

        /**
            X value
        */
        float value;

        /**
            X/Y values
        */
        vec2 values;

    }
}

/**
    A paremeter binding
*/
struct ParameterBinding {
private:
    Parameter* param;

public:
    /**
        The minimum value range the binding will hit
    */
    float min;

    /**
        The maximum value range the binding will hit
    */
    float max;

    /**
        The weight of this binding
    */
    float weight;

    /**
        Creates a new binding
    */
    this(Parameter* param, float min, float max, float weight) {
        this.param = param;
        this.min = min;
        this.max = max;
    }

    /**
        Updates the bound parameter
    */
    void update(float value) {
        param.value = value;
    }
}