/**
    JSON Writer

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
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
    import nulib.conv : to;
    final switch(node.type) {
        case DataNodeType.undefined:
            return;
        
        case DataNodeType.blob_:
            return;
        
        case DataNodeType.boolean_:
            writer.writeUTF8(node.tryCoerce!bool ? "true" : "false");
            return;
        
        case DataNodeType.int_:
            auto v = to!string(node.tryCoerce!int);
            writer.writeUTF8(v[]);
            return;

        case DataNodeType.uint_:
            auto v = to!string(node.tryCoerce!uint);
            writer.writeUTF8(v[]);
            return;

        case DataNodeType.float_:
            auto v = to!string(node.tryCoerce!float);
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
            foreach(i, key, ref value; node.object) {

                writer.writeJsonString(key);
                writer.writeLE(':');
                writer.writeJsonImpl(value);

                if (i+1 < node.length)
                    writer.writeLE(',');
            }
            writer.writeLE('}');
            return;
    }
}