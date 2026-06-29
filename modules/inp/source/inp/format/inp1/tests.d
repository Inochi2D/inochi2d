/**
    INP1 Format Tests

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inp.format.inp1.tests;
import inp.format.inp1;
import inp.format.node;
import nulib.io.stream;
import inp.format;

@("read-write")
unittest {
    DataNode obj = DataNode.createObject();
    obj[INP_TAG_PAYLOAD] = DataNode.createObject();
    obj[INP_TAG_PAYLOAD]["a"] = 42;
    obj[INP_TAG_PAYLOAD]["b"] = "Hello, world!";

    MemoryStream mstream = new MemoryStream(255);    
    mstream.writeINP1(obj);
    mstream.seek(0);

    auto result = mstream.readINP1();
    assert(result, result.error);
    auto node = result.get();

    assert(node[INP_TAG_PAYLOAD]["a"].number == 42);
    assert(node[INP_TAG_PAYLOAD]["b"].text == "Hello, world!");
}