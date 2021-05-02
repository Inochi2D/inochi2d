/*
    Inochi2D Spline Group

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.pathdeform;
import inochi2d.core.nodes;
import inochi2d.math;

/**
    A node that deforms multiple nodes against a path.
*/
class PathDeform : Node {
private:
    vec2[] jointOrigins;

    mat3[] computedJoints;
    void recomputeJoints() {
        foreach(i; 0..joints.length) {
            size_t next = i+1;
            
            // Special Case:
            // We're at the end of the joints list
            // There's nothing to "orient" ourselves against, so
            // We'll just have a rotational value of 0
            if (next >= joints.length) {
                computedJoints[i] = mat3.translation(joints[i]);
                break; // We're already at the end, no need to check condition again
            }

            // Get the angles between our origin positions and our
            // Current joint positions to get the difference.
            // The difference between the root angle and the current
            // angle determines how much the point and path is rotated.
            immutable(float) startAngle = atan2(
                jointOrigins[i].y - jointOrigins[next].y, 
                jointOrigins[i].x - jointOrigins[next].x
            );

            immutable(float) endAngle = atan2(
                joints[i].y - joints[next].y, 
                joints[i].x - joints[next].x
            );

            // Apply our wonky math to our computed joint
            computedJoints[i] = mat3.translation(joints[i]) * mat3.zrotation(startAngle-endAngle);
        }
    }

public:
    /**
        The joints of the deformation
    */
    vec2[] joints;

    /**
        The bindings from joints to verticies in multiple parts

        [Part] = Every part that is affected
        [] = the entry of the joint
        size_t[] = the entry of verticies in that part that should be affected.
    */
    size_t[][][Part] bindings;

    /**
        Updates the spline group.
    */
    override
    void update() {
        this.recomputeJoints();
        


        super.update();
    }

    /**
        Resets the positions of joints
    */
    void resetJoints() {
        joints = jointOrigins;
        computedJoints.length = joints.length;
    }
}