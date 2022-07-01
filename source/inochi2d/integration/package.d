/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.integration;

version(InRenderless) {
    struct TextureBlob {
        ubyte tag;
        ubyte[] data;
    }

    TextureBlob[] inCurrentPuppetTextureSlots;
} else {

}