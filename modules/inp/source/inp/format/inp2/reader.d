/**
    INP2 Format Reader

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.inp2.reader;
import inp.format.node;
import inp.format.inp2;
import inp.crc;
import nulib.io.stream;
import nulib.io.stream.rw;
import nulib.math;
import numem;

@nogc:

/**
    Reads an INP2 File.

    Params:
        stream = The stream to read.
    
    Returns:
        A result type containing either a $(D DataNode)
        or an error message.
*/
Result!DataNode readINP2(Stream stream) @nogc {
    scope StreamReader reader = new StreamReader(stream);
    DataNode result;

    size_t start = stream.tell();
    
    // Verify magic bytes.
    auto magic = reader.readUTF8(8);
    if (magic != INP2_MAGIC) {
        stream.seek(start);
        return error!DataNode("Invalid magic bytes!");
    }

    // Read the tags.
    if (string err = reader.readINP2Impl(result)) {
        nogc_delete(result);
        stream.seek(start);
        return error!DataNode(err);
    }
    return ok(result.move());
}




//
//              IMPLEMENTATION DETAILS
//
private:

/// Realigns the reader.
void realignINP2(StreamReader reader) {
    reader.stream.seek(nu_alignup(reader.stream.tell(), 4));
}

uint peekTagINP2(StreamReader reader) {
    uint tag = reader.readU32LE();
    reader.stream.seek(-4, SeekOrigin.relative);
    return tag;
}

string readKeyINP2(StreamReader reader) {
    uint tag = reader.readU32LE();
    if ((tag & INP2_TAG_MASK) != INP2_TAG_KEY)
        return null;

    uint len = tag >> 8;

    auto key = reader.readUTF8(len);
    reader.realignINP2();
    return key.take();
}

string readINP2Impl()(StreamReader reader, ref DataNode node) {
    uint tag = reader.readU32LE();
    switch(tag & INP2_TAG_MASK) {
        default:    return null;

        case INP2_TAG_UINT:
            node = DataNode(reader.readU32LE());
            return null;

        case INP2_TAG_INT:
            node = DataNode(reader.readI32LE());
            return null;

        case INP2_TAG_FLOAT:
            node = DataNode(reader.readF32LE());
            return null;

        case INP2_TAG_STRING:
            uint len = reader.readU32LE();
            auto str = reader.readUTF8(len);
            node = DataNode(str[]);
            reader.realignINP2();
            return null;
        
        case INP2_TAG_BLOB:
            uint len    = reader.readU32LE();
            ubyte[] buffer = nu_malloca!ubyte(len);

            reader.stream.read(buffer);
            reader.realignINP2();
            uint crc = reader.readU32LE();
            if (crc32(buffer) != crc) {
                return "Malformed CRC";
            }

            node = DataNode(buffer);
            nu_freea(buffer);
            return null;

        case INP2_TAG_ARRAY_BEGIN:
            uint count = tag >> 8;
            node = DataNode.createArray();
            foreach(i; 0..count) {
                
                // Array ended early? Escape.
                if (reader.peekTagINP2() == INP2_TAG_ARRAY_END)
                    break;
                
                DataNode value;
                if (auto error = reader.readINP2Impl(value))
                    return error;
                
                node ~= value.move();
            }
            return null;

        case INP2_TAG_OBJECT_BEGIN:
            uint count = tag >> 8;
            node = DataNode.createObject();
            foreach(i; 0..count) {
                
                // Array ended early? Escape.
                if (reader.peekTagINP2() == INP2_TAG_OBJECT_END)
                    break;
                
                if (string key = reader.readKeyINP2()) {
                    DataNode value;
                    if (auto error = reader.readINP2Impl(value))
                        return error;
                    
                    node[key] = value;
                    nu_freea(key);
                }
            }
            return null;

    }
}