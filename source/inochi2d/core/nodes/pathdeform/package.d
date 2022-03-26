/*
    Inochi2D Bone Group

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.pathdeform;
import inochi2d.fmt.serialize;
import inochi2d.core.nodes.part;
import inochi2d.core.nodes;
import inochi2d.core.dbg;
import inochi2d.core;
import inochi2d.math;

package(inochi2d) {
    void inInitPathDeform() {
        inRegisterNodeType!PathDeform;
    }
}

/**
    A node that deforms multiple nodes against a path.
*/
@TypeId("PathDeform")
class PathDeform : Node {
private:
    
    // Joint Origins
    vec2[] jointOrigins;

    // Computed joint matrices
    mat3[] computedJoints;


    void recomputeJoints() {
        foreach(i; 0..joints.length) {
            float startAngle;
            float endAngle;
            size_t next = i+1;
            
            // Special Case:
            // We're at the end of the joints list
            // There's nothing to "orient" ourselves against, so
            // We'll just have a rotational value of 0
            if (next >= joints.length) {
                startAngle = atan2(
                    jointOrigins[i-1].y - jointOrigins[i].y, 
                    jointOrigins[i-1].x - jointOrigins[i].x
                );
                
                endAngle = atan2(
                    joints[i-1].y - joints[i].y, 
                    joints[i-1].x - joints[i].x
                );
            } else {

                // Get the angles between our origin positions and our
                // Current joint positions to get the difference.
                // The difference between the root angle and the current
                // angle determines how much the point and path is rotated.
                startAngle = atan2(
                    jointOrigins[i].y - jointOrigins[next].y, 
                    jointOrigins[i].x - jointOrigins[next].x
                );

                endAngle = atan2(
                    joints[i].y - joints[next].y, 
                    joints[i].x - joints[next].x
                );
            }


            // Apply our wonky math to our computed joint
            computedJoints[i] = mat3.translation(vec3(joints[i], 0)) * mat3.zrotation(startAngle-endAngle);
        }
    }

    /**
        Bindings queued for finalization
    */
    size_t[][][uint] queuedBindings;
    
protected:

    override
    string typeId() { return "PathDeform"; }

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void serializeSelf(ref InochiSerializer serializer) {
        super.serializeSelf(serializer);
        serializer.putKey("joints");
        auto state = serializer.arrayBegin();
            foreach(joint; jointOrigins) {
                serializer.elemBegin;
                joint.serialize(serializer);
            }
        serializer.arrayEnd(state);

        serializer.putKey("bindings");
        state = serializer.arrayBegin();
            foreach(item, data; bindings) {
                serializer.elemBegin;
                auto obj = serializer.objectBegin();
                    serializer.putKey("bound_to");
                    serializer.putValue(item.uuid);
                    serializer.putKey("bind_data");
                    serializer.serializeValue(data);
                serializer.objectEnd(obj);
            }
        serializer.arrayEnd(state);
    }

    /**
        Allows serializing self data (with compact serializer)
    */
    override
    void serializeSelf(ref InochiSerializerCompact serializer) {
        super.serializeSelf(serializer);
        serializer.putKey("joints");
        auto state = serializer.arrayBegin();
            foreach(joint; jointOrigins) {
                serializer.elemBegin;
                joint.serialize(serializer);
            }
        serializer.arrayEnd(state);

        if (bindings.length > 0) {
            serializer.putKey("bindings");
            state = serializer.arrayBegin();
                foreach(item, data; bindings) {

                    // (Safety measure) Skip null items
                    if (item is null) continue;

                    serializer.elemBegin;
                    auto obj = serializer.objectBegin();
                        serializer.putKey("bound_to");
                        serializer.putValue(item.uuid);
                        
                        serializer.putKey("bind_data");
                        serializer.serializeValue(data);
                    serializer.objectEnd(obj);
                }
            serializer.arrayEnd(state);
        }

        // TODO: serialize bindings
    }

    override
    SerdeException deserializeFromFghj(Fghj data) {
        super.deserializeFromFghj(data);
        
        foreach(jointData; data["joints"].byElement) {
            vec2 val;
            val.deserialize(jointData);
            
            jointOrigins ~= val;
        }
        joints = jointOrigins.dup;
        this.computedJoints = new mat3[joints.length];

        if (!data["bindings"].isEmpty) {
            foreach(bindingData; data["bindings"].byElement) {
                uint uuid;
                size_t[][] qdata;
                bindingData["bound_to"].deserializeValue(uuid);
                bindingData["bind_data"].deserializeValue(qdata);
                queuedBindings[uuid] = qdata;
            }
        }

        // TODO: deserialize bindings
        return null;
    }

public:

    /**
        The current joint locations of the deformation
    */
    vec2[] joints;

    /**
        The bindings from joints to verticies in multiple parts

        [Drawable] = Every drawable that is affected
        [] = the entry of the joint
        size_t[] = the entry of verticies in that part that should be affected.
    */
    size_t[][][Drawable] bindings;

    /**
        Gets joint origins
    */
    vec2[] origins() {
        return jointOrigins;
    }

    /**
        Constructs a new path deform
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        Constructs a new path deform
    */
    this(vec2[] joints, Node parent = null) {
        this.setJoints(joints);
        super(parent);
    }

    /**
        Sets the joints for this path deform
    */
    void setJoints(vec2[] joints) {
        this.jointOrigins = joints.dup;
        this.joints = joints.dup;
        this.computedJoints = new mat3[joints.length];
    }

    /**
        Adds a joint with the specified offset to the end of the joints list
    */
    void addJoint(vec2 joint) {
        jointOrigins ~= jointOrigins[$-1] + joint;
        joints ~= jointOrigins[$-1];
        computedJoints.length++;
    }

    /**
        Sets the position of joint as its new origin
    */
    void setJointOriginFor(size_t index) {
        if (index >= joints.length) return;
        jointOrigins[index] = joints[index];
    }

    /**
        Updates the spline group.
    */
    override
    void update() {
        this.recomputeJoints();

        // Iterates over every part attached to this deform
        // Then iterates over every joint that should affect that part
        // Then appplies the deformation across that part's joints
        foreach(Drawable part, size_t[][] entry; bindings) {
            if (part is null) continue;
            MeshData mesh = part.getMesh();
            
            foreach(jointEntry, vertList; entry) {
                mat3 joint = computedJoints[jointEntry];

                // Deform vertices
                foreach(i; vertList) {
                    part.vertices[i] = (joint * vec3(mesh.vertices[i], 0)).xy;
                }
            }
        }

        super.update();
    }

    
    void drawHandles() {
        
    }

    /**
        Resets the positions of joints
    */
    void resetJoints() {
        joints = jointOrigins;
        computedJoints.length = joints.length;
    }

    override
    void finalize() {
        super.finalize();
        
        // Finalize by moving the data over to the actual bindings
        foreach(uuid, data; queuedBindings) {
            bindings[puppet.find!Drawable(uuid)] = data.dup;
        }

        // Clear this memory
        destroy(queuedBindings);
    }
}