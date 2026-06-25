/**
    INP 1 Format Reader

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.inp1.reader;
import inp.format.json.reader;
import inp.format.node;
import inp.format.inp1;
import nulib.io.stream.rw;
import nulib.io.stream;
import nulib.math;
import numem;

import inp.format : 
    INP_TAG_PAYLOAD, 
    INP_TAG_TEXTURES, 
    INP_TAG_VENDOR;

@nogc:

/**
    Reads an INP1 File.

    Params:
        stream = The stream to read.
    
    Returns:
        A result type containing either a $(D DataNode)
        or an error message.
*/
Result!DataNode readINP1(Stream stream) @nogc {
    scope StreamReader reader = new StreamReader(stream);
    DataNode result;

    size_t start = stream.tell();
    reader.readINP1Impl(result);
    stream.seek(start);

    return ok(result.move());
}



//
//              IMPLEMENTATION DETAILS
//
private:

void readINP1Impl()(StreamReader reader, ref DataNode node) {
    node = DataNode.createObject();
    node[INP_TAG_PAYLOAD] = DataNode.createObject();
    node[INP_TAG_TEXTURES] = DataNode.createArray();
    node[INP_TAG_VENDOR] = DataNode.createObject();

    ptrdiff_t streamLength = reader.stream.length;
    readLoop: while(reader.stream.tell < streamLength) {
        auto key = reader.readUTF8(8);
        switch(key) {
            default:
                break readLoop;

            case INP1_MAGIC:
                ptrdiff_t rstart = reader.stream.tell;
                uint payloadLength = reader.readU32BE();
                auto result = reader.readJson(node[INP_TAG_PAYLOAD], payloadLength);
                break;

            case INP_TAG_TEXTURES:
                uint count = reader.readU32BE();
                foreach(i; 0..count) {
                    
                    // Main data
                    uint dataLength = reader.readU32BE();
                    ubyte encoding = reader.readU8();

                    if (dataLength > 0) {
                        DataNode result = DataNode.createObject();
                        ubyte[] data = nu_malloca!ubyte(dataLength);
                        reader.stream.read(data);

                        result["encoding"] = encoding;
                        result["data"] = data;
                        node[INP_TAG_TEXTURES] ~= result;

                        nu_freea(data);
                    }
                }
                break;

            case INP_TAG_VENDOR:
                uint count = reader.readU32BE();
                foreach(i; 0..count) {
                    auto keyLength = reader.readU32BE();
                    auto dataKey = reader.readUTF8(keyLength).take();
                    auto dataLength = reader.readU32BE();
                    auto dataValue = nu_malloca!ubyte(dataLength);

                    reader.stream.read(dataValue);
                    node[INP_TAG_VENDOR][dataKey] = dataValue;
                    
                    nu_freea(dataValue);
                    nu_freea(dataKey);
                }
                break;
        }
    }
}