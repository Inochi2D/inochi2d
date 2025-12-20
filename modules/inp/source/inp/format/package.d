module inp.format;

import nulib.io.stream;
import numem.optional;

public import inp.format.inp1;
public import inp.format.inp2;
public import inp.format.node;

/**
    The different INP file formats.
*/
enum INPFileFormat : uint {
    unknown = 0x00,
    inp1    = 0x01,
    inp2    = 0x02
}

/**
    Determins the INP file format stored within the given stream.

    Params:
        stream = The stream to detect the INP file format for.
    
    Returns:
        The INP version of the file.
*/
INPFileFormat detectFormat(Stream stream) @nogc nothrow {
    assert(stream.canRead(), "Stream is not readable!");
    assert(stream.canSeek(), "Stream is not seekable!");

    size_t start = stream.tell();
    ubyte[8] magic;
    
    // Try reading magic bytes, length must be 8.
    if (stream.read(magic) != 8) {
        stream.seek(start);
        return INPFileFormat.unknown;
    }

    stream.seek(start);
    switch(cast(string)magic) {
        default:            return INPFileFormat.unknown;
        case INP1_MAGIC:    return INPFileFormat.inp1;
        case INP2_MAGIC:    return INPFileFormat.inp2;
    }
}

/**
    Reads an INP File from a stream.

    Params:
        stream = The stream to read from, must be readable and seekable.
    
    Returns:
        A result that contains a $(D DataNode) on success,
        otherwise contains an error.
*/
Result!DataNode readINP(Stream stream) @nogc {
    final switch(detectFormat(stream)) {
        case INPFileFormat.unknown:
            return error!DataNode("Unknown file format!");
        
        case INPFileFormat.inp1:
            return error!DataNode("TODO");

        case INPFileFormat.inp2:
            return readINP2(stream);
    }
}

/**
    Writes the given $(D DataNode) to the given $(D Stream).

    Params:
        stream =    The stream to write to, must be writable.
        node =      The node containing INP data.
        format =    The file format to write, INP2 is recommended.
*/
void writeINP(Stream stream, ref DataNode node, INPFileFormat format = INPFileFormat.inp2) @nogc {
    final switch(format) {
        case INPFileFormat.unknown:
            return;

        case INPFileFormat.inp1:
            stream.writeINP1(node);
            return;
            
        case INPFileFormat.inp2:
            stream.writeINP2(node);
            return;
    }
}