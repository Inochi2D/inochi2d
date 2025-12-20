/**
    INP2 Format Writer

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.inp2.writer;
import inp.format.node;
import inp.format.inp2;
import inp.crc;
import nulib.io.stream;
import nulib.io.stream.rw;
import nulib.math;
import numem;

@nogc:

/**
    Write the contents of a DataNode into the INP File.

    Params:
        stream =    The stream to write to.
        node =      A DataNode object following the INP structure.
*/
void writeINP2(Stream stream, ref DataNode node) {
    StreamWriter writer = nogc_new!StreamWriter(stream);
    writer.writeUTF8(INP2_MAGIC);
    writer.writeINP2Impl(node);
    nogc_delete(writer);
}




//
//              IMPLEMENTATION DETAILS
//
private:

/// Function which pads null bytes until the alignment is correct.
void writeINP2Padding(StreamWriter writer) {
    size_t location = writer.stream.tell();
    ubyte[4] null_ = [0x00, 0x00, 0x00, 0x00];
    writer.stream.write(null_[0..nu_alignup(location, 4)-location]);
}

void writeINP2Key(StreamWriter writer, string key) {
    writer.writeLE!uint(cast(uint)(INP2_TAG_KEY | (min(key.length, 255) << 8)));
    writer.writeUTF8(key[0..min(key.length, 255)]);
    writer.writeINP2Padding();
}

void writeINP2Impl()(StreamWriter writer, auto ref DataNode node) {
    final switch(node.type) {
        case DataNodeType.undefined:
            writer.writeLE!uint(INP2_TAG_NIL);
            return;
        
        case DataNodeType.int_:
            writer.writeLE!uint(INP2_TAG_INT);
            writer.writeLE!int(node.tryCoerce!int);
            return;
        
        case DataNodeType.uint_:
            writer.writeLE!uint(INP2_TAG_UINT);
            writer.writeLE!uint(node.tryCoerce!uint);
            return;
        
        case DataNodeType.float_:
            writer.writeLE!uint(INP2_TAG_FLOAT);
            writer.writeLE!float(node.tryCoerce!float);
            return;
        
        case DataNodeType.string_:
            writer.writeLE!uint(INP2_TAG_STRING);
            writer.writeLE!uint(cast(uint)node.text.length);
            writer.writeUTF8(node.text);
            writer.writeINP2Padding();
            return;
        
        case DataNodeType.blob_:
            writer.writeLE!uint(INP2_TAG_BLOB);
            writer.writeLE!uint(cast(uint)node.blob.length);
            writer.stream.write(node.blob);
            writer.writeINP2Padding();

            // Blobs have crc32 checksums.
            writer.writeLE(crc32(node.blob));
            return;
        
        case DataNodeType.array_:
            writer.writeLE!uint(cast(uint)(INP2_TAG_ARRAY_BEGIN | node.length << 8));
            foreach(n; node.array) {
                writer.writeINP2Impl(n);
            }
            writer.writeLE!uint(INP2_TAG_ARRAY_END);
            return;
        
        case DataNodeType.object_:
            writer.writeLE!uint(cast(uint)(INP2_TAG_OBJECT_BEGIN | node.length << 8));
            foreach(ref kv; node.object) {
                writer.writeINP2Key(kv.key);
                writer.writeINP2Impl(kv.value);
            }
            writer.writeLE!uint(INP2_TAG_OBJECT_END);
            return;
    }
}