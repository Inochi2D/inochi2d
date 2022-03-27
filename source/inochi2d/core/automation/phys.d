/*
    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.automation.phys;
import inochi2d.core.automation;
import inochi2d;
import std.math;

struct VerletNode {
    float distance = 1f;
    vec2 position;
    vec2 oldPosition;
    
    this(vec2 pos) {
        this.position = pos;
        this.oldPosition = pos;
    }

    /**
        Serializes a parameter
    */
    void serialize(S)(ref S serializer) {
        auto state = serializer.objectBegin;
            serializer.putKey("distance");
            serializer.putValue(distance);
            serializer.putKey("position");
            position.serialize(serializer);
            serializer.putKey("old_position");
            oldPosition.serialize(serializer);
        serializer.objectEnd(state);
    }

    /**
        Deserializes a parameter
    */
    SerdeException deserializeFromFghj(Fghj data) {
        data["distance"].deserializeValue(distance);
        position.deserialize(data["position"]);
        oldPosition.deserialize(data["old_position"]);
        return null;
    }
}

@TypeId("physics")
class PhysicsAutomation : Automation {
protected:

    void simulate(size_t i, ref AutomationBinding binding) {
        auto node = &nodes[i];

        vec2 tmp = node.position;
        node.position = (node.position - node.oldPosition) + vec2(0, gravity) * (deltaTime * deltaTime) * bounciness;
        node.oldPosition = tmp;
    }

    void constrain() {
        foreach(i; 0..nodes.length-1) {
            auto node1 = &nodes[i];
            auto node2 = &nodes[i+1];

            // idx 0 = first node in param, this always is the reference node.
            // We base our "hinge" of the value of this reference value
            if (i == 0) {
                node1.position = vec2(bindings[i].getAxisValue(), 0);
            }

            // Then we calculate the distance of the difference between
            // node 1 and 2, 
            float diffX = node1.position.x - node2.position.x;
            float diffY = node1.position.y - node2.position.y;
            float dist = node1.position.distance(node2.position);
            float diff = 0;

            // We need the distance to be larger than 0 so that
            // we don't get division by zero problems.
            if (dist > 0) {
                diff = (nodes[i].distance - dist) / dist;
            }

            // Apply out fancy new link
            vec2 trans = vec2(diffX, diffY) * (.5 * diff);
            node1.position += trans;
            node2.position -= trans;

            // Clamp so that we don't start flopping above the hinge above us
            node2.position.y = clamp(node2.position.y, node1.position.y, float.max);
        }
    }

    override
    void onUpdate() {
        if (bindings.length > 1) {

            // simulate each link in our chain
            foreach(i, ref binding; bindings) {
                this.simulate(i, binding);
            }

            foreach(i; 0..4+(bindings.length*2)) {
                this.constrain();
            }
        }
    }

    override
    void serializeSelf(ref InochiSerializer serializer) {
        serializer.putKey("nodes");
        serializer.serializeValue(nodes);
        serializer.putKey("damping");
        serializer.putValue(damping);
        serializer.putKey("bounciness");
        serializer.putValue(bounciness);
        serializer.putKey("gravity");
        serializer.putValue(gravity);
    }

    override
    void serializeSelf(ref InochiSerializerCompact serializer) {
        serializer.putKey("nodes");
        serializer.serializeValue(nodes);
        serializer.putKey("damping");
        serializer.putValue(damping);
        serializer.putKey("bounciness");
        serializer.putValue(bounciness);
        serializer.putKey("gravity");
        serializer.putValue(gravity);
    }

    override
    void deserializeSelf(Fghj data) {
        data["nodes"].deserializeValue(nodes);
        data["damping"].deserializeValue(damping);
        data["bounciness"].deserializeValue(bounciness);
        data["gravity"].deserializeValue(gravity);
    }
public:

    /**
        A node in the internal verlet simulation
    */
    VerletNode[] nodes;

    /**
        Amount of damping to apply to movement
    */
    float damping = 0.05f;

    /**
        How bouncy movement should be
        1 = default bounciness
    */
    float bounciness = 1f;

    /**
        Gravity to apply to each link
    */
    float gravity = 20f;

    /**
        Adds a binding
    */
    override
    void bind(AutomationBinding binding) {
        super.bind(binding);

        nodes ~= VerletNode(vec2(0, 1));
    }

    this(Puppet parent) {
        this.typeId = "physics";
        super(parent);
    }
}

mixin InAutomation!PhysicsAutomation;