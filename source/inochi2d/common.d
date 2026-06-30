/**
    Data structures used commonly throughout.

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.common;
import nulib.string;

/**
    Magic value meaning that the model has no thumbnail
*/
enum NO_THUMBNAIL = uint.max;

/**
    Creates an Inochi2D version number.
*/
enum uint IN_MAKE_VERSION(ushort major, ubyte minor, ubyte patch) =
    (cast(uint)major << 16) |
    (cast(uint)minor << 8) |
    (cast(uint)patch);

/**
    IO Sink Interface for errors, warnings, etc.
*/
struct IOSink {
@nogc:

    /**
        Error sink to write errors to.
    */
    void function(const(char)* msg, const(char)* file, uint line) @nogc nothrow error;

    /**
        Warning sink to write warnings to.
    */
    void function(const(char)* msg, const(char)* file, uint line) @nogc nothrow warning;

    /**
        Info sink to write informational messages to.
    */
    void function(const(char)* msg, const(char)* file, uint line) @nogc nothrow info;
}

/**
    Model loading state information.
*/
struct ModelState {
@nogc:

    /**
        IO Sink
    */
    IOSink io;

    /**
        Is the model a 0.8 legacy model?
    */
    bool doUpgrade08;

    /**
        Inochi2D Specification version.
    */
    uint version_;

    /**
        Writes an error to the error sink.

        Params:
            msg =   The message.
            file =  The file the error occured in.
            line =  The line of the file the error occured in.
    */
    pragma(inline, true)
    void error(nstring msg, const(char)* file = __MODULE__.ptr, uint line = __LINE__) {
        if (io.error)
            io.error(msg.ptr, file, line);
    }

    /**
        Writes an error to the error sink.

        Params:
            msg =   The message.
            file =  The file the error occured in.
            line =  The line of the file the error occured in.
    */
    pragma(inline, true)
    void error(const(char)* msg, const(char)* file = __MODULE__.ptr, uint line = __LINE__) {
        if (io.error)
            io.error(msg, file, line);
    }

    /**
        Writes an warning to the warning sink.

        Params:
            msg =   The message.
            file =  The file the warning occured in.
            line =  The line of the file the warning occured in.
    */
    pragma(inline, true)
    void warning(nstring msg, const(char)* file = __MODULE__.ptr, uint line = __LINE__) {
        if (io.warning)
            io.warning(msg.ptr, file, line);
    }

    /**
        Writes an warning to the warning sink.

        Params:
            msg =   The message.
            file =  The file the warning occured in.
            line =  The line of the file the warning occured in.
    */
    pragma(inline, true)
    void warning(const(char)* msg, const(char)* file = __MODULE__.ptr, uint line = __LINE__) {
        if (io.warning)
            io.warning(msg, file, line);
    }

    /**
        Writes info to the info sink.

        Params:
            msg =   The message.
            file =  The file the message was emitted from.
            line =  The line the message was emitted from.
    */
    pragma(inline, true)
    void info(nstring msg, const(char)* file = __MODULE__.ptr, uint line = __LINE__) {
        if (io.info)
            io.info(msg.ptr, file, line);
    }

    /**
        Writes info to the info sink.

        Params:
            msg =   The message.
            file =  The file the message was emitted from.
            line =  The line the message was emitted from.
    */
    pragma(inline, true)
    void info(const(char)* msg, const(char)* file = __MODULE__.ptr, uint line = __LINE__) {
        if (io.info)
            io.info(msg, file, line);
    }
}