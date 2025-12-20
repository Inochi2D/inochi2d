module inp.format;
import nulib.io.stream;

public import inp.format.inp1;
public import inp.format.inp2;

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