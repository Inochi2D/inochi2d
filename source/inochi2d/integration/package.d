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

    string inPartMaskShader = import("basic/basic-mask.frag");
    string inPartFragmentShader = import("basic/basic.frag");
    string inPartVertexShader = import("basic/basic.vert");

    string inCompositeMaskShader = import("basic/composite-mask.frag");
    string inCompositeFragmentShader = import("basic/composite.frag");
    string inCompositeVertexShader = import("basic/composite.vert");

    string inMaskFragmentShader = import("mask.frag");
    string inMaskVertexShader = import("mask.vert");


} else {

}