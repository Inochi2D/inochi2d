/**
    INP 1 Format Writer

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.inp1.writer;
import inp.format.node;
import inp.format.inp1;
import nulib.io.stream;
import nulib.io.stream.rw;
import nulib.math;
import numem;

@nogc:

void writeINP1(Stream stream, ref DataNode node) {
    StreamWriter writer = nogc_new!StreamWriter(stream);

    if (INP1_MAGIC in node) {
        writer.writeUTF8(INP1_MAGIC);

        ubyte[] payload = node[INP1_MAGIC].makeJsonPayload();
        writer.writeLE!uint(cast(uint)payload.length);
        stream.write(payload);

        nu_freea(payload);
    }

    if ("TEX_SECT" in node) {
        writer.writeUTF8("TEX_SECT");
        writer.writeLE!uint(cast(uint)node["TEX_SECT"].length);
        foreach(ref v; node["TEX_SECT"].array) {
            writer.writeLE!uint(cast(uint)v["data"].blob.length);
            writer.writeLE!ubyte(v["encoding"].tryCoerce!ubyte);
            stream.write(v["data"].blob);
        }
    }

    if ("EXT_SECT" in node) {
        writer.writeUTF8("EXT_SECT");
        writer.writeLE!uint(cast(uint)node["EXT_SECT"].length);
        foreach(ref kv; node["EXT_SECT"].object) {
            writer.writeLE!uint(cast(uint)kv.key.length);
            writer.writeUTF8(kv.key);
            writer.writeLE!uint(cast(uint)kv.value.blob.length);
            stream.write(kv.value.blob);
        }
    }

    nogc_delete(writer);
}




//
//              IMPLEMENTATION DETAILS
//
private:

ubyte[] makeJsonPayload(ref DataNode node) {
    ubyte[] result;

    MemoryStream stream = nogc_new!MemoryStream(1);
    StreamWriter writer = nogc_new!StreamWriter(stream);

    writer.writeJson(node);
    result = stream.take();

    nogc_delete(writer);
    nogc_delete(stream);
    return result;
}

void writeJsonString(StreamWriter writer, string text) {
    writer.writeUTF8("\"");
    writer.writeUTF8(text);
    writer.writeUTF8("\"");
}

void writeJson()(StreamWriter writer, auto ref DataNode node) {
    import nulib.conv : to_string;
    final switch(node.type) {
        case DataNodeType.undefined:
            return;
        
        case DataNodeType.blob_:
            return;
        
        case DataNodeType.int_:
            auto v = to_string(node.tryCoerce!int);
            writer.writeUTF8(v[]);
            return;

        case DataNodeType.uint_:
            auto v = to_string(node.tryCoerce!uint);
            writer.writeUTF8(v[]);
            return;

        case DataNodeType.float_:
            auto v = to_string(node.tryCoerce!float);
            writer.writeUTF8(v[]);
            return;
        
        case DataNodeType.string_:
            writer.writeJsonString(node.text);
            return;
        
        case DataNodeType.array_:
            writer.writeUTF8("[");
            foreach(i, ref n; node.array) {
                writer.writeJson(n);
                if (i+1 < node.length)
                    writer.writeUTF8(",");
            }
            writer.writeUTF8("]");
            return;
        
        case DataNodeType.object_:
            writer.writeUTF8("{");
            foreach(i, kv; node.object) {

                writer.writeJsonString(kv.key);
                writer.writeUTF8(":");
                writer.writeJson(kv.value);

                if (i+1 < node.length)
                    writer.writeUTF8(",");
            }
            writer.writeUTF8("}");
            return;
    }
}