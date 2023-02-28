/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d;
//public import inochi2d.inochi2d;
public import inochi2d.math;
public import inochi2d.phys;
public import inochi2d.fmt;
public import inochi2d.core;
public import inochi2d.ver;

private double currentTime_ = 0;
private double lastTime_ = 0;
private double deltaTime_ = 0;
private double function() tfunc_;

/**
    Initializes Inochi2D
    Run this after OpenGL context has been set current
*/
void inInit(double function() timeFunc) {
    initRenderer();
    tfunc_ = timeFunc;
}

void inSetTimingFunc(double function() timeFunc) {
    tfunc_ = timeFunc;
}

/**
    Run this at the start of your render/game loop
*/
void inUpdate() {
    currentTime_ = tfunc_();
    deltaTime_ = currentTime_-lastTime_;
    lastTime_ = currentTime_;
}

/**
    Gets the time difference between the last frame and the current frame
*/
double deltaTime() {
    return deltaTime_;
}

/**
    Gets the last frame's time step
*/
double lastTime() {
    return lastTime_;
}

/**
    Gets the current time step
*/
double currentTime() {
    return currentTime_;
}