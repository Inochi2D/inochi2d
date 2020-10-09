/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d;
public import inochi2d.puppet;
public import inochi2d.math;
public import inochi2d.phys;
public import inochi2d.fmt;
public import inochi2d.render;

/**
    Initializes Inochi2D
    Run this after OpenGL context has been set current
*/
void initInochi2D() {
    initDynMesh();
}