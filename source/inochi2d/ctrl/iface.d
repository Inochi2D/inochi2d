/**
    Macro Control Interface

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.ctrl.iface;
import nulib.quark;

/**
	Interface implemented by macro sources.

	Macro sources produce values to a series of output ports,
	these ports may be connected to a sink to consume them.
*/
interface IMacroSource {
@nogc nothrow:
		
	/**
		Names of the output ports to the macro.
	*/
	@property quark[] outputs() pure;

	/**
		Gets the value of the given output port.

		Params:
			name = The name of the port to get the value from.

		Returns:
			The floating point value in the port on success,
			$(D NaN) on failure.
	*/
	float getValue(quark name);
}

/**
	Interface implemented by macro sinks.

	Macro sinks store values into input ports, these inputs may
	be set by the end user or by a source.
*/
interface IMacroSink {
		
	/**
		Names of the input ports of the macro.
	*/
	@property quark[] inputs();

	/**
		Sets the value of an input in a source macro.

		Params:
			name = 	The name of the input port.
			value =	The value to set the input port to.
	*/
	bool setValue(quark name, float value);
}