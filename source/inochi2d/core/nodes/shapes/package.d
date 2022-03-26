/*
    Inochi2D Shapes Node

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.shapes;
import inochi2d.core.nodes.part;
import inochi2d.core.nodes;
import inochi2d.core;
import inochi2d.math;

/**
    A Shape Node
*/
struct ShapeNode {
    /**
        The breakpoint in which the Shape Node activates
    */
    vec2 breakpoint;

    /**
        The shape data
    */
    vec2[] shapeData;
}

/**
    NOTE: This needs to be here to allow for deserialization of this type
*/
mixin InNode!Shapes;

/**
    Contains various deformation shapes that can be applied to
    children of this node
*/
@TypeId("Shapes")
class Shapes : Node {
protected:

    override
    string typeId() { return "Shapes"; }
    
public:
    /**
        Constructs a new Shapes node
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        A list of the shape offsets to apply per part
    */
    ShapeNode[][Drawable] shapes;

    /**
        The cursor inside the Shapes node
    */
    vec2 selector;

    override
    void update() {
        foreach(Drawable part, nodes; shapes) {
            
            size_t nodeLen = nodes.length;
            float[] weights = new float[nodeLen];
            float accWeight = 0;

            enum MAX_DIST = 1.5;

            // Calculate weighted average for each breakpoint
            for(size_t i = 0; i < nodes.length; i++) {
                weights[i] = MAX_DIST-(nodes[i].breakpoint.distance(selector)/MAX_DIST);
                accWeight += weights[i];
            }

            // Acount for weights outside 1.0
            if (accWeight > 1) {
                for(size_t i = 0; i < weights.length; i++) {
                    weights[i] /= nodeLen;
                }
            }

            // Make sure our vertices buffer is ready
            vec2[] vertices = new vec2[part.vertices.length];
            foreach(i; 0..vertices.length) {
                vertices[i] = vec2(0);
            }

            // Apply our weighted offsets
            foreach(node; nodes) {
                for (size_t i = 0; i < node.shapeData.length; i++) {
                    vertices[i] += weights[i] * node.shapeData[i];
                }
            }
            
        }
    }
}