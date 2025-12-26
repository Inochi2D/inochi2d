/**
    INP 1 Format Reader

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.inp1.reader;
import inp.format.node;
import inp.format.inp1;
import nulib.io.stream.rw;
import nulib.io.stream;
import nulib.math;
import numem;
import inp.format.json.reader;

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
    node[INP1_MAGIC] = DataNode.createObject();
    node["TEX_SECT"] = DataNode.createArray();
    node["EXT_SECT"] = DataNode.createObject();

    ptrdiff_t streamLength = reader.stream.length;
    readLoop: while(reader.stream.tell < streamLength) {
        auto key = reader.readUTF8(8);

        switch(key) {
            default:
                break readLoop;

            case INP1_MAGIC:
                uint payloadLength = reader.readU32LE();
                reader.readJson(node[INP1_MAGIC], payloadLength);
                break;

            case "TEX_SECT":
                uint count = reader.readU32LE();
                foreach(i; 0..count) {
                    
                    // Main data
                    uint dataLength = reader.readU32LE();
                    ubyte encoding = reader.readU8();
                    if (dataLength > 0) {
                        DataNode result = DataNode.createObject();
                        ubyte[] data = nu_malloca!ubyte(dataLength);

                        result["encoding"] = encoding;
                        result["data"] = data;
                        node["TEX_SECT"] ~= result;

                        nu_freea(data);
                    }
                }
                break;

            case "EXT_SECT":
                uint count = reader.readU32LE();
                foreach(i; 0..count) {
                    auto dataKey = reader.readUTF8(reader.readU32LE());
                    auto dataValue = nu_malloca!ubyte(reader.readU32LE());
                    reader.stream.read(dataValue);
                    node["EXT_SECT"][dataKey] = dataValue;
                    nu_freea(dataValue);
                }

                break;
        }
    }
}