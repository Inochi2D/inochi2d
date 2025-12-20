/**
    INP2 Format Tests

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.inp2.tests;
import inp.format.inp2;
import inp.format.node;
import nulib.io.stream;

@("read-write")
unittest {
    import inp.format.inp2;
    
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