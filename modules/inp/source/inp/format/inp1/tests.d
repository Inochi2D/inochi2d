/**
    INP1 Format Tests

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.inp1.tests;
import inp.format.inp1;
import inp.format.node;
import nulib.io.stream;

@("read-write")
unittest {
    DataNode obj = DataNode.createObject();
    obj[INP1_MAGIC] = DataNode.createObject();
    obj[INP1_MAGIC]["a"] = 42;
    obj[INP1_MAGIC]["b"] = "Hello, world!";

    MemoryStream mstream = new MemoryStream(255);    
    mstream.writeINP1(obj);
    mstream.seek(0);

    auto result = mstream.readINP1();
    assert(result, result.error);
    auto node = result.get();

    assert(node[INP1_MAGIC]["a"].number == 42);
    assert(node[INP1_MAGIC]["b"].text == "Hello, world!");
}