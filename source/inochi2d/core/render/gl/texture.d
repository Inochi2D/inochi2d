/*
    Inochi2D GL Texture

    Copyright © 2023, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.render.gl.texture;
import inochi2d.core.render.texture;
import inochi2d.core.texture;
import bindbc.opengl;
import std.exception;
import std.format;
import imagefmt;
import inmath;
import inochi2d;

/**
    A texture, only format supported is unsigned 8 bit RGBA
*/
class GLTexture : Texture {
private:
    GLuint id;
    int width_;
    int height_;
    Wrapping wrapping_;
    Filtering filtering_;

    GLuint inColorMode_;
    GLuint outColorMode_;
    int bpc_;
    int channels_;

    GLuint toColorMode(int bpc, int channels) {
        switch(channels) {
            case 1:
                return GL_RED;
            case 2:
                return GL_RG;
            case 3:
                switch(bpc) {
                    case 8:
                        return GL_RGB8;
                    case 16:
                        return GL_RGB16;
                    case 32:
                        return GL_RGB32F;
                    default:
                        return GL_RGB;
                }
            case 4:
                switch(bpc) {
                    case 8:
                        return GL_RGBA8;
                    case 16:
                        return GL_RGBA16;
                    case 32:
                        return GL_RGBA32F;
                    default:
                        return GL_RGBA;
                }
            default: 
                enforce(0, "Unsupported channel count %s".format(channels));
        }
        return 0;
    }

    uint uuid;

public:

    /**
        Loads texture from image file
        Supported file types:
        * PNG 8-bit
        * PNG 16-bit
        * BMP 8-bit
        * TGA 8-bit non-palleted
        * JPEG baseline
    */
    this(string file, int channels = 0, int bpc = 8) {
        import std.file : read;

        // Ensure we keep this ref alive until we're done with it
        ubyte[] fData = cast(ubyte[])read(file);

        // Load image from disk, as RGBA 8-bit
        IFImage image = read_image(fData, 0, bpc);
        enforce( image.e == 0, "%s: %s".format(IF_ERROR[image.e], file));
        scope(exit) image.free();

        // Load in image data to OpenGL
        this(image.buf8, image.w, image.h, image.c, bpc, channels == 0 ? image.c : channels);
        uuid = inCreateUUID();
    }

    /**
        Creates a texture from a ShallowTexture
    */
    this(TextureData data) {
        this(data.data, data.width, data.height, data.channels);
    }

    /**
        Creates a new empty texture
    */
    this(int width, int height, int channels = 4) {

        // Create an empty texture array with no data
        ubyte[] empty = new ubyte[width_*height_*channels];

        // Pass it on to the other texturing
        this(empty, width, height, channels, channels);
    }

    /**
        Creates a new texture from specified data
    */
    this(ubyte[] data, int width, int height, int inChannels = 4, int bpc=8, int outChannels = 4) {
        this.width_ = width;
        this.height_ = height;
        this.channels_ = outChannels;
        this.bpc_ = bpc;

        this.inColorMode_ = toColorMode(bpc, inChannels);
        this.outColorMode_ = toColorMode(bpc, outChannels);

        // Generate OpenGL texture
        glGenTextures(1, &id);
        this.setData(data);

        // Set default filtering and wrapping
        this.setFiltering(Filtering.Linear);
        this.setWrapping(Wrapping.Clamp);
        this.setAnisotropy(inRendererGetForThisThread().getMaxAnisotropy()/2.0);
        uuid = inCreateUUID();
    }

    ~this() {
        dispose();
    }

    /**
        Width of texture
    */
    override
    int getWidth() {
        return width_;
    }

    /**
        Height of texture
    */
    override
    int getHeight() {
        return height_;
    }

    /**
        Gets the OpenGL color mode
    */
    GLuint colorMode() {
        return outColorMode_;
    }

    /**
        Gets the channel count
    */
    override
    int getChannels() {
        return channels_;
    }

    /**
        Gets the channel count
    */
    override
    int getBitsPerPixel() {
        return bpc_;
    }

    /**
        Center of texture
    */
    vec2i getCenter() {
        return vec2i(width_/2, height_/2);
    }

    /**
        Gets the size of the texture
    */
    vec2i getSize() {
        return vec2i(width_, height_);
    }

    /**
        Gets the runtime UUID for the texture
    */
    override
    uint getRuntimeUUID() {
        return uuid;
    }

    /**
        Sets the runtime UUID for the texture
    */
    override
    void setRuntimeUUID(uint uuid) {
        this.uuid = uuid;
    }

    /**
        Set the filtering mode used for the texture
    */
    override
    void setFiltering(Filtering filtering) {
        this.bind();
        filtering_ = filtering;
        glTexParameteri(
            GL_TEXTURE_2D, 
            GL_TEXTURE_MIN_FILTER, 
            filtering == Filtering.Linear ? GL_LINEAR_MIPMAP_LINEAR : GL_NEAREST
        );

        glTexParameteri(
            GL_TEXTURE_2D, 
            GL_TEXTURE_MAG_FILTER, 
            filtering == Filtering.Linear ? GL_LINEAR : GL_NEAREST
        );
    }

    override
    void setAnisotropy(float value) {
        this.bind();
        
        glTexParameterf(
            GL_TEXTURE_2D,
            GL_TEXTURE_MAX_ANISOTROPY,
            clamp(value, 1, inRendererGetForThisThread().getMaxAnisotropy())
        );
    }

    /**
        Set the wrapping mode used for the texture
    */
    override
    void setWrapping(Wrapping wrapping) {
        this.bind();

        wrapping_ = wrapping;
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrapping);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrapping);
        glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, [0f, 0f, 0f, 0f].ptr);
    }
    
    /**
        Gets the wrapping mode of the texture
    */
    override
    Wrapping getWrapping() {
        return wrapping_;
    }
    
    /**
        Gets the filtering mode of the texture
    */
    override
    Filtering getFiltering() {
        return filtering_;
    }

    /**
        Sets the data of the texture
    */
    override
    void setData(ubyte[] data) {
        this.bind();
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        glPixelStorei(GL_PACK_ALIGNMENT, 1);
        glTexImage2D(GL_TEXTURE_2D, 0, outColorMode_, width_, height_, 0, inColorMode_, GL_UNSIGNED_BYTE, data.ptr);
        
        this.genMipmap();
    }

    /**
        Generate mipmaps
    */
    override
    void genMipmap() {
        this.bind();
        glGenerateMipmap(GL_TEXTURE_2D);
    }

    /**
        Sets a region of a texture to new data
    */
    void setDataRegion(ubyte[] data, int x, int y, int width, int height, int channels = 4) {
        this.bind();

        // Make sure we don't try to change the texture in an out of bounds area.
        enforce( x >= 0 && x+width <= this.width_, "x offset is out of bounds (xoffset=%s, xbound=%s)".format(x+width, this.width_));
        enforce( y >= 0 && y+height <= this.height_, "y offset is out of bounds (yoffset=%s, ybound=%s)".format(y+height, this.height_));

        GLuint inChannelMode = GL_RGBA;
        if (channels == 1) inChannelMode = GL_RED;
        else if (channels == 2) inChannelMode = GL_RG;
        else if (channels == 3) inChannelMode = GL_RGB;

        // Update the texture
        glTexSubImage2D(GL_TEXTURE_2D, 0, x, y, width, height, inChannelMode, GL_UNSIGNED_BYTE, data.ptr);

        this.genMipmap();
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

    /**
        Saves the texture to file
    */
    override
    void save(string file) {
        write_image(file, width_, height_, getTextureData(true), channels_);
    }

    /**
        Gets the texture data for the texture
    */
    override
    ubyte[] getTextureData(bool unmultiply=false) {
        ubyte[] buf = new ubyte[width_*height_*channels_];
        bind();
        glGetTexImage(GL_TEXTURE_2D, 0, outColorMode_, GL_UNSIGNED_BYTE, buf.ptr);
        if (unmultiply && channels_ == 4) {
            inTexUnPremuliply(buf);
        }
        return buf;
    }

    /**
        Gets this texture's texture id
    */
    GLuint getTextureId() {
        return id;
    }

    /**
        Disposes texture from GL
    */
    override
    void dispose() {
        glDeleteTextures(1, &id);
        id = 0;
    }
}