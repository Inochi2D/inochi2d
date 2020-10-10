/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.inochi2d.puppet;
import inochi2d.inochi2d;
import inochi2d.math;

/**
    A Puppet
*/
class Puppet {
public:
    /**
        The scene the puppet belongs to
    */
    Scene scene;

    /**
        The puppet's parts
    */
    Part[] parts;

    /**
        Draw the puppet
    */
    void draw() {
        foreach(part; parts) {
            part.draw();
        }
    }
}