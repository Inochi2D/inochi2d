/**
    INP2 Format Tests

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inp.format.inp2.tests;
import inp.format.inp2;
import inp.format.node;
import nulib.io.stream;

@("read-write")
unittest {
    import inp.format.inp2;
    
    import std.stdio : writefln;
    import nulib.digest.crc : crc32;
    writefln("%x", crc32(cast(ubyte[])"Hello, world!"));

    DataNode obj = DataNode.createObject();
    obj["a"] = 42;
    obj["b"] = "Hello, world!";

    MemoryStream mstream = new MemoryStream(255);    
    mstream.writeINP2(obj);
    mstream.seek(0);

    auto result = mstream.readINP2();

    assert(result, result.error);
    auto node = result.get();
    
    assert(node["a"].number == 42);
    assert(node["b"].text == "Hello, world!");
}