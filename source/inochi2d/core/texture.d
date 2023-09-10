/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.texture;
import inochi2d.core.render;
import inochi2d.core.nodes;
import inochi2d.math;
import std.exception;
import std.format;
import bindbc.opengl;
import imagefmt;
import std.stdio;

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
        Bits per pixel
    */
    int bpc;

    /**
        Amount of color channels
    */
    int channels;

    /**
        Whether the texture data is compressed for GPU usage.

        This should only be true for formats such as BPTC, S3TC, etc.
    */
    bool compressed = false;

    /**
        Loads a shallow texture from image file
        Supported file types:
        * PNG 8-bit
        * BMP 8-bit
        * TGA 8-bit non-palleted
        * JPEG baseline
    */
    this(string file, int channels = 0, int bpc=8) {
        import std.file : read;

        // Ensure we keep this ref alive until we're done with it
        ubyte[] fData = cast(ubyte[])read(file);

        // Load image from disk, as <channels> 8-bit
        IFImage image = read_image(fData, 0, bpc);
        enforce( image.e == 0, "%s: %s".format(IF_ERROR[image.e], file));
        scope(exit) image.free();

        // Copy data from IFImage to this ShallowTexture
        this.data = new ubyte[image.buf8.length];
        this.data[] = image.buf8;

        // Set the width/height data
        this.width = image.w;
        this.height = image.h;
        this.channels = image.c;
        this.bpc = bpc;
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
    this(ubyte[] buffer, int channels = 0, int bpc=8, bool compressed=false) {
        this.compressed = compressed;

        if (!this.compressed) {
            // Load image from disk, as <channels> 8-bit
            IFImage image = read_image(buffer, 0, bpc);
            enforce( image.e == 0, "%s".format(IF_ERROR[image.e]));
            scope(exit) image.free();

            // Copy data from IFImage to this ShallowTexture
            this.data = new ubyte[image.buf8.length];
            this.data[] = image.buf8;

            // Set the width/height data
            this.width = image.w;
            this.height = image.h;
            this.channels = image.c;
            this.bpc = bpc;
        } else {
            this.data = new ubyte[buffer.length];
            this.data[] = buffer;

            // TODO: Handle compressed texture data width/height
        }
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
        this.bpc = 8;
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

pragma(inline, true)
void inTexPremultiply(ref TextureData data) {
    inTexPremultiply(data.data, data.channels, data.bpc);
}
pragma(inline, true)
void inTexUnPremultiply(ref TextureData data) {
    if (data.channels < 4) return;
    if (data.bpc != 8)     return; // TODO: 16 bit un-premultiply.

    inTexUnPremuliply(data.data);
}

void inTexPremultiply(ref ubyte[] data, int channels = 4, int bpc=8) {
    if (channels < 4) return;
    if (bpc != 8) return; // TODO: 16 bit premultiply.

    foreach(i; 0..data.length/channels) {

        size_t offsetPixel = (i*channels);
        data[offsetPixel+0] = cast(ubyte)((cast(int)data[offsetPixel+0] * cast(int)data[offsetPixel+3])/255);
        data[offsetPixel+1] = cast(ubyte)((cast(int)data[offsetPixel+1] * cast(int)data[offsetPixel+3])/255);
        data[offsetPixel+2] = cast(ubyte)((cast(int)data[offsetPixel+2] * cast(int)data[offsetPixel+3])/255);
    }
}

void inTexUnPremuliply(ref ubyte[] data, int bpc=8) {
    foreach(i; 0..data.length/4) {
        if (data[((i*4)+3)] == 0) continue;

        data[((i*4)+0)] = cast(ubyte)(cast(int)data[((i*4)+0)] * 255 / cast(int)data[((i*4)+3)]);
        data[((i*4)+1)] = cast(ubyte)(cast(int)data[((i*4)+1)] * 255 / cast(int)data[((i*4)+3)]);
        data[((i*4)+2)] = cast(ubyte)(cast(int)data[((i*4)+2)] * 255 / cast(int)data[((i*4)+3)]);
    }
}

/**
    A runtime texture
*/
struct RuntimeTexture {
    
    /// UID of texture
    uint uid;

    /// Width of texture
    uint width;
    
    /// Height of texture
    uint height;

    /// Amount of channels
    uint channels;

    /// Backend API data
    void* apiData;

    /**
        Creates a runtime texture from a TextureData object
    */
    this(ref TextureData data, uint uid=InInvalidUID) {
        import inochi2d.core.render;
        this.apiData = inRenderAllocateTexture(data, data.channels);
        this.width = data.width;
        this.height = data.height;
        this.channels = data.channels;
        if (uid == InInvalidUID) {
            uid = inCreateUID();
        }
    }

    ~this() {
        inRenderDeallocateTexture(apiData);
    }
}