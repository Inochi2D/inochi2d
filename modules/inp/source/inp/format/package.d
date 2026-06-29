/**
    INP Format

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
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
    Tag for the INP payload section.
*/
enum char[8] INP_TAG_PAYLOAD = "INP_SECT";

/**
    Tag for the INP texture section.
*/
enum char[8] INP_TAG_TEXTURES = "TEX_SECT";

/**
    Tag for the INP extended vendor data section.
*/
enum char[8] INP_TAG_VENDOR = "EXT_SECT";

/**
    Texture format ID for PNG.
*/
enum ubyte INP_TEX_FMT_PNG = 0;

/**
    Texture format ID for TGA.
*/
enum ubyte INP_TEX_FMT_TGA = 1;

/**
    Texture format ID for BC7.
*/
enum ubyte INP_TEX_FMT_BC7 = 2;

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
    switch(cast(char[8])magic) {
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
            return readINP1(stream);

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