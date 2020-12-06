/*
    Inochi2D Rendering

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.render;

public import inochi2d.render.shader;
public import inochi2d.render.texture;
public import inochi2d.render.mesh;

import bindbc.opengl;
import inochi2d.math;

// Internal rendering constants
private {
    // Viewport
    int inViewportWidth;
    int inViewportHeight;

    // Camera
    Camera inCamera;
}

/**
    Gets the global camera
*/
Camera inGetCamera() {
    return inCamera;
}

/**
    Sets the global camera
*/
void inSetCamera(Camera camera) {
    inCamera = camera;
}

/**
    Sets the viewport area to render to
*/
void inSetViewport(int width, int height) {
    glViewport(0, 0, width, height);
    inViewportWidth = width;
    inViewportHeight = height;
}

/**
    Gets the viewport
*/
void inGetViewport(out int width, out int height) {
    width = inViewportWidth;
    height = inViewportHeight;
}

static this() {

    // Some defaults that should be changed by app writer
    inCamera = new Camera;
    inSetViewport(640, 480);
}