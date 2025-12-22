/**
    JSON Writer

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.json.writer;
import inp.format.node;
import nulib.io.stream;
import nulib.io.stream.rw;
import nulib.math;
import numem;

@nogc:

/**
    Writes $(D DataNode) to stream as JSON.

    Params:
        stream =    The stream to write to
        node =      The node to write.
*/
void writeJson(Stream stream, ref DataNode node) {
    StreamWriter writer = nogc_new!StreamWriter(stream);
    writer.writeJsonImpl(node);
    nogc_delete(writer);
}


//
//              IMPLEMENTATION DETAILS
//
private:

void writeJsonString(StreamWriter writer, string text) {
    writer.writeUTF8("\"");
    foreach(char c; text) {
        if (c == '"') {
            writer.writeUTF8("\\\"");
            continue;
        }

        writer.writeLE!ubyte(c);
    }
    writer.writeUTF8(text);
    writer.writeUTF8("\"");
}

void writeJsonImpl()(StreamWriter writer, auto ref DataNode node) {
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
                writer.writeJsonImpl(n);
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
                writer.writeJsonImpl(kv.value);

                if (i+1 < node.length)
                    writer.writeUTF8(",");
            }
            writer.writeUTF8("}");
            return;
    }
}