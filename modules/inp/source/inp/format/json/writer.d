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
    scope StreamWriter writer = new StreamWriter(stream);
    writer.writeJsonImpl(node);
}


//
//              IMPLEMENTATION DETAILS
//
private:

void writeJsonString(StreamWriter writer, string text) {
    writer.writeLE('"');
    foreach(char c; text) {
        if (c == '"') {
            writer.writeLE('\\');
            writer.writeLE('"');
            continue;
        }

        writer.writeLE!ubyte(c);
    }
    writer.writeLE('"');
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
            writer.writeLE('[');
            foreach(i, ref n; node.array) {
                writer.writeJsonImpl(n);
                if (i+1 < node.length)
                    writer.writeLE(',');
            }
            writer.writeLE(']');
            return;
        
        case DataNodeType.object_:
            writer.writeLE('{');
            foreach(i, kv; node.object) {

                writer.writeJsonString(kv.key);
                writer.writeLE(':');
                writer.writeJsonImpl(kv.value);

                if (i+1 < node.length)
                    writer.writeLE(',');
            }
            writer.writeLE('}');
            return;
    }
}