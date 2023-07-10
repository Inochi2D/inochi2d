/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.texture;
import inochi2d.math;
import std.exception;
import std.format;
import bindbc.opengl;
import imagefmt;
import std.stdio;
import inochi2d.core.nodes : inCreateUUID;

/**
    Filtering mode for texture
*/
enum Filtering {
    /**
        Linear filtering will try to smooth out textures
    */
    Linear,

    /**
        Point filtering will try to preserve pixel edges.
        Due to texture sampling being float based this is imprecise.
    */
    Point
}

/**
    Texture wrapping modes
*/
enum Wrapping {
    /**
        Clamp texture sampling to be within the texture
    */
    Clamp = GL_CLAMP_TO_BORDER,

    /**
        Wrap the texture in every direction idefinitely
    */
    Repeat = GL_REPEAT,

    /**
        Wrap the texture mirrored in every direction indefinitely
    */
    Mirror = GL_MIRRORED_REPEAT
}

/**
    A texture which is not bound to an OpenGL context
    Used for texture atlassing
*/
struct TextureData {
public:
    /**
        8-bit RGBA color data
    */
    ubyte[] data;

    /**
        Width of texture
    */
    int width;

    /**
        Height of texture
    */
    int height;

    /**
        Amount of color channels
    */
    int channels;

    /**
        Amount of channels to conver to when passed to OpenGL
    */
    int convChannels;

    /**
        Loads a shallow texture from image file
        Supported file types:
        * PNG 8-bit
        * BMP 8-bit
        * TGA 8-bit non-palleted
        * JPEG baseline
    */
    this(string file, int channels = 0) {
        import std.file : read;

        // Ensure we keep this ref alive until we're done with it
        ubyte[] fData = cast(ubyte[])read(file);

        // Load image from disk, as <channels> 8-bit
        IFImage image = read_image(fData, 0, 8);
        enforce( image.e == 0, "%s: %s".format(IF_ERROR[image.e], file));
        scope(exit) image.free();

        // Copy data from IFImage to this ShallowTexture
        this.data = new ubyte[image.buf8.length];
        this.data[] = image.buf8;

        // Set the width/height data
        this.width = image.w;
        this.height = image.h;
        this.channels = image.c;
        this.convChannels = channels == 0 ? image.c : channels;
    }

    /**
        Loads a shallow texture from image buffer
        Supported file types:
        * PNG 8-bit
        * BMP 8-bit
        * TGA 8-bit non-palleted
        * JPEG baseline

        By setting channels to a specific value you can force a specific color mode
    */
    this(ubyte[] buffer, int channels = 0) {

        // Load image from disk, as <channels> 8-bit
        IFImage image = read_image(buffer, 0, 8);
        enforce( image.e == 0, "%s".format(IF_ERROR[image.e]));
        scope(exit) image.free();

        // Copy data from IFImage to this ShallowTexture
        this.data = new ubyte[image.buf8.length];
        this.data[] = image.buf8;

        // Set the width/height data
        this.width = image.w;
        this.height = image.h;
        this.channels = image.c;
        this.convChannels = channels == 0 ? image.c : channels;
    }
    
    /**
        Loads uncompressed texture from memory
    */
    this(ubyte[] buffer, int w, int h, int channels = 4) {
        this.data = buffer;

        // Set the width/height data
        this.width = w;
        this.height = h;
        this.channels = channels;
        this.convChannels = channels;
    }
    
    /**
        Loads uncompressed texture from memory
    */
    this(ubyte[] buffer, int w, int h, int channels = 4, int convChannels = 4) {
        this.data = buffer;

        // Set the width/height data
        this.width = w;
        this.height = h;
        this.channels = channels;
        this.convChannels = convChannels;
    }

    /**
        Saves image
    */
    void save(string file) {
        import std.file : write;
        import core.stdc.stdlib : free;
        int e;
        ubyte[] sData = write_image_mem(IF_PNG, this.width, this.height, this.data, channels, e);
        enforce(!e, "%s".format(IF_ERROR[e]));

        write(file, sData);

        // Make sure we free the buffer
        free(sData.ptr);
    }
}

void inTexPremultiply(ref ubyte[] data, int channels = 4) {
    if (channels < 4) return;

    foreach(i; 0..data.length/channels) {

        size_t offsetPixel = (i*channels);
        data[offsetPixel+0] = cast(ubyte)((cast(int)data[offsetPixel+0] * cast(int)data[offsetPixel+3])/255);
        data[offsetPixel+1] = cast(ubyte)((cast(int)data[offsetPixel+1] * cast(int)data[offsetPixel+3])/255);
        data[offsetPixel+2] = cast(ubyte)((cast(int)data[offsetPixel+2] * cast(int)data[offsetPixel+3])/255);
    }
}

void inTexUnPremuliply(ref ubyte[] data) {
    foreach(i; 0..data.length/4) {
        if (data[((i*4)+3)] == 0) continue;

        data[((i*4)+0)] = cast(ubyte)(cast(int)data[((i*4)+0)] * 255 / cast(int)data[((i*4)+3)]);
        data[((i*4)+1)] = cast(ubyte)(cast(int)data[((i*4)+1)] * 255 / cast(int)data[((i*4)+3)]);
        data[((i*4)+2)] = cast(ubyte)(cast(int)data[((i*4)+2)] * 255 / cast(int)data[((i*4)+3)]);
    }
}