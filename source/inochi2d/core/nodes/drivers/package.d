/*
    Inochi2D Composite Node

    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Asahi Lina
*/
module inochi2d.core.nodes.drivers;
import inochi2d.core.nodes.common;
//import inochi2d.core.nodes;
import inochi2d.core;
public import inochi2d.core.nodes.drivers.simplephysics;

/**
    Driver abstract node type
*/
@TypeId("Driver", 0x00000003)
@TypeIdAbstract
abstract class Driver : Node {
protected:
    this() { }

    /**
        Constructs a new Driver node
    */
    this(GUID guid, Node parent = null) {
        super(guid, parent);
    }

public:
    override
    void preUpdate(DrawList drawList) {
        super.preUpdate(drawList);
    }

    override
    void update(float delta, DrawList drawList) {
        super.update(delta, drawList);
    }

    Parameter[] getAffectedParameters() {
        return [];
    }

    final
    bool affectsParameter(ref Parameter param) {
        foreach(ref Parameter p; getAffectedParameters()) {
            if (p.guid == param.guid) return true;
        } 
        return false;
    }

    abstract void reset();
}
