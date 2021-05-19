/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.texture;
import std.exception;
import std.format;
import bindbc.opengl;
import imagefmt;

/**
    Filtering mode for texture
*/
enum Filtering {
    /**
        Linear filtering will try to smooth out textures
    */
    Linear = GL_LINEAR,

    /**
        Point filtering will try to preserve pixel edges.
        Due to texture sampling being float based this is imprecise.
    */
    Point = GL_POINT
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
struct ShallowTexture {
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
        Loads a shallow texture from image file
        Supported file types:
        * PNG 8-bit
        * BMP 8-bit
        * TGA 8-bit non-palleted
        * JPEG baseline
    */
    this(string file) {

        // Load image from disk, as RGBA 8-bit
        IFImage image = read_image(file, 4, 8);
        enforce( image.e == 0, "%s: %s".format(IF_ERROR[image.e], file));
        scope(exit) image.free();

        // Copy data from IFImage to this ShallowTexture
        this.data = new ubyte[image.buf8.length];
        this.data[] = image.buf8;

        // Set the width/height data
        this.width = image.w;
        this.height = image.h;
    }
}

/**
    A texture, only format supported is unsigned 8 bit RGBA
*/
class Texture {
private:
    GLuint id;
    int width_;
    int height_;

    GLuint colorMode;
    int alignment;

public:

    /**
        Loads texture from image file
        Supported file types:
        * PNG 8-bit
        * BMP 8-bit
        * TGA 8-bit non-palleted
        * JPEG baseline
    */
    this(string file) {

        // Load image from disk, as RGBA 8-bit
        IFImage image = read_image(file, 4, 8);
        enforce( image.e == 0, "%s: %s".format(IF_ERROR[image.e], file));
        scope(exit) image.free();

        // Load in image data to OpenGL
        this(image.buf8, image.w, image.h);
    }

    /**
        Creates a texture from a ShallowTexture
    */
    this(ShallowTexture shallow) {
        this(shallow.data, shallow.width, shallow.height);
    }

    /**
        Creates a new empty texture
    */
    this(int width, int height, GLuint mode = GL_SRGB_ALPHA, int alignment = 4) {

        // Create an empty texture array with no data
        ubyte[] empty = new ubyte[width_*height_*alignment];

        // Pass it on to the other texturing
        this(empty, width, height, mode, alignment);
    }

    /**
        Creates a new texture from specified data
    */
    this(ubyte[] data, int width, int height, GLuint mode = GL_SRGB_ALPHA, int alignment = 4) {
        this.colorMode = mode;
        this.alignment = alignment;
        this.width_ = width;
        this.height_ = height;
        
        // Generate OpenGL texture
        glGenTextures(1, &id);
        this.setData(data);

        // Set default filtering and wrapping
        this.setFiltering(Filtering.Linear);
        this.setWrapping(Wrapping.Repeat);
    }

    /**
        Width of texture
    */
    int width() {
        return width_;
    }

    /**
        Height of texture
    */
    int height() {
        return height_;
    }

    /**
        Set the filtering mode used for the texture
    */
    void setFiltering(Filtering filtering) {
        this.bind();
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filtering);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filtering);
    }

    /**
        Set the wrapping mode used for the texture
    */
    void setWrapping(Wrapping wrapping) {
        this.bind();
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrapping);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrapping);
    }

    /**
        Sets the data of the texture
    */
    void setData(ubyte[] data) {
        this.bind();
        glPixelStorei(GL_UNPACK_ALIGNMENT, alignment);
        glTexImage2D(GL_TEXTURE_2D, 0, colorMode, width_, height_, 0, GL_RGBA, GL_UNSIGNED_BYTE, data.ptr);
        glGenerateMipmap(GL_TEXTURE_2D);
    }

    /**
        Sets a region of a texture to new data
    */
    void setDataRegion(ubyte[] data, int x, int y, int width, int height) {
        this.bind();

        // Make sure we don't try to change the texture in an out of bounds area.
        enforce( x >= 0 && x+width <= this.width_, "x offset is out of bounds (xoffset=%s, xbound=%s)".format(x+width, this.width_));
        enforce( y >= 0 && y+height <= this.height_, "y offset is out of bounds (yoffset=%s, ybound=%s)".format(y+height, this.height_));

        // Update the texture
        glPixelStorei(GL_UNPACK_ALIGNMENT, alignment);
        glTexSubImage2D(GL_TEXTURE_2D, 0, x, y, width, height, this.colorMode, GL_UNSIGNED_BYTE, data.ptr);
        glGenerateMipmap(GL_TEXTURE_2D);
    }

    /**
        Bind this texture
        
        Notes
        - In release mode the unit value is clamped to 31 (The max OpenGL texture unit value)
        - In debug mode unit values over 31 will assert.
    */
    void bind(uint unit = 0) {
        assert(unit <= 31u, "Outside maximum OpenGL texture unit value");
        glActiveTexture(GL_TEXTURE0+(unit <= 31u ? unit : 31u));
        glBindTexture(GL_TEXTURE_2D, id);
    }
}