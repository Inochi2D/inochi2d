/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/
module inochi2d.ffi.scene;
import inochi2d.ffi.puppet;

import inochi2d.puppet.scene;
import inochi2d.puppet.puppet;

import numem.all;

import core.stdc.stdio : FILE;

@nogc extern(C) export:

/// Scene reference
alias InSceneRef = void*;

/**
    Creates a scene
*/
InSceneRef inSceneCreate() {
    return cast(InSceneRef)nogc_new!Scene();
}

/**
    Destroys and frees a scene
*/
void inSceneDestroy(InSceneRef scene) {
    if (scene) {
        Scene _scene = cast(Scene)scene;
        nogc_delete!Scene(_scene);
    }
}

/**
    Loads a puppet from a C file.
*/
InPuppetRef inSceneLoadPuppetFromFile(InSceneRef scene, FILE* file) {
    FileStream strean = nogc_new!FileStream(file);
    Puppet puppet = (cast(Scene)scene).loadPuppet(strean);

    nogc_delete(strean);
    return cast(InPuppetRef)puppet;
}

/**
    Loads a puppet from memory
*/
InPuppetRef inSceneLoadPuppetFromMemory(InSceneRef scene, ubyte* data, size_t length) {
    MemoryStream strean = nogc_new!MemoryStream(data, length);
    Puppet puppet = (cast(Scene)scene).loadPuppet(strean);

    nogc_delete(strean);
    return cast(InPuppetRef)puppet;
}