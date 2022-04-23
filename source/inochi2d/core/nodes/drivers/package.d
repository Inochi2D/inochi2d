/*
    Inochi2D Composite Node

    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Asahi Lina
*/
module inochi2d.core.nodes.drivers;
import inochi2d.core.nodes.common;
import inochi2d.core.nodes;
import inochi2d.core;
public import inochi2d.core.nodes.drivers.simplephysics;

/**
    Driver abstract node type
*/
@TypeId("Driver")
abstract class Driver : Node {
private:
    this() { }

protected:
    /**
        Constructs a new Driver node
    */
    this(uint uuid, Node parent = null) {
        super(uuid, parent);
    }

public:
    override
    void beginUpdate() {
        super.beginUpdate();
    }

    override
    void update() {
        super.update();
    }

    Parameter[] getAffectedParameters() {
        return [];
    }

    abstract void updateDriver();

    abstract void reset();

    void drawDebug() {
    }
}
