/**
    Inochi2D Parameter Sink

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.ctrl.sinks.param;
import inochi2d.core.property;
import inochi2d.core;
import inochi2d.ctrl;
import nulib.quark;

/**
    A parameter which controls a puppet.

    Parameters are output sinks which has no sources (outputs),
    as such you cannot control one parameter with another parameter.

    A parameter without any controllers is implicitly a controller
    itself.
*/
class Parameter(size_t N) : MacroNode, IMacroSink {
private:
@nogc:
    quark[N] axesNames_;
    RList!(StorageBuffer, N) data_;
    float[N] value_ = 0;

protected:

    /**
        Callback executed when the node is to run a update cycle.
    
        Params:
            delta = Time since last frame.
    */
    override
    void onUpdate(float delta) {
        assert(0, "TODO: Implement this.");
    }

public:

    this() {
        this.axesNames_ = [X, Y, Z, W][0..N];
    }

    /**
        Names of the input ports of the macro.
    */
    @property quark[] inputs() => axesNames_;

    /**
        Gets whether the given node has an input port with a given
        port name.

        Params:
            port = The port to query.

        Returns:
            $(D true) if the node has a given input port,
            $(D false) otherwise.
    */

    override
    bool hasInput(quark port) {
        foreach(axis; axesNames_) {
            if (axis == port)
                return true;
        }
        return false;
    }

    /**
        Sets the value of an input in a source macro.

        Params:
            name =  The name of the input port.
            value = The value to set the input port to.
    */
    bool setValue(quark name, float value) {
        static foreach(i; 0..N) {
            if (name == axesNames_[i]) {
                value_[i] = value;
                return true;
            }
        }
        return false;
    }
}

alias Parameter1D = Parameter!(1);
alias Parameter2D = Parameter!(2);

// quarks for the different axes.
mixin RegisterQuarks!();
@propkey("x") __gshared immutable(quark) X;
@propkey("y") __gshared immutable(quark) Y;
@propkey("z") __gshared immutable(quark) Z;
@propkey("w") __gshared immutable(quark) W;