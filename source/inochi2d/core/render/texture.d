/**
    Inochi2D Textures

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.render.texture;
import inochi2d.core.render.resource;
import nulib.io.stream;
import numath;
import numem;
import gamut;

/**
    Format of texture data.
*/
enum TextureFormat : uint {

    /**
        None or unknown encoding.
    */
    none = 0,

    /**
        RGBA8 data.
    */
    rgba8Unorm = 1,

    /**
        Red-channel only mask data.
    */
    r8 = 2
}

/**
    A texture.
*/
class Texture : Resource {
public:
@nogc:

    /**
        Texture data.
    */
    TextureData data;

    /**
        Creates a new texture.

        Params:
            width = The requested width of the texture,
            height = The requested height of the texture,
            format = The requested format of the texture,
    */
    static Texture create(uint width, uint height, TextureFormat format) {
        return nogc_new!Texture(width, height, format);
    }

    /**
        Creates a new texture with the given texture data.

        Params:
            data = The data to use for creation.
    */
    static Texture createForData(TextureData data) {
        return nogc_new!Texture(data);
    }

    /**
        Length of the resource's data allocation in bytes.
    */
    override @property uint length() => cast(uint)data.data.length;

    /**
        Format of the texture.
    */
    final @property TextureFormat format() => data.format;

    /**
        Width of the texture in pixels.
    */
    final @property uint width() => data.width;

    /**
        Height of the texture in pixels.
    */
    final @property uint height() => data.height;

    /**
        Channel count of the texture.
    */
    final @property uint channels() => data.channels;

    /**
        Pixel data of the texture.
    */
    final @property void[] pixels() => data.data;

    // Destructor
    ~this() {
        data.free();
    }

    /**
        Constructs a new texture.
    */
    this(uint width, uint height, TextureFormat format) {
        data.width = width;
        data.height = height;
        data.format = format;
    }

    /**
        Constructs a new texture.
    */
    this(TextureData data) {
        this.data = data;
    }

    /**
        Resizes the texture.
    */
    void resize(uint width, uint height) {
        data.resize(width, height);
    }
}

/**
    Texture Data used during GPU uploads.
*/
struct TextureData {
public:
@nogc:
    uint width;
    uint height;
    TextureFormat format;
    void[] data;

    /**
        Amount of color channels in the image.
    */
    @property uint channels() {
        final switch (format) {
        case TextureFormat.rgba8Unorm:
            return 4;

        case TextureFormat.r8:
            return 1;

        case TextureFormat.none:
            return 0;
        }
    }

    static TextureData load(ubyte[] data) {
        TextureData result;
        try {
            Image img;
            if (!img.loadFromMemory(data, LAYOUT_GAPLESS | LAYOUT_VERT_STRAIGHT | LOAD_8BIT | LOAD_NO_PREMUL))
                throw nogc_new!NuException(img.errorMessage());

            switch(img.type) with(PixelType) {
                case unknown:   throw nogc_new!NuException("Unknown pixel format for texture!");

                case l8:
                    result.format = TextureFormat.r8;
                    break;

                case rgba8:
                    result.format = TextureFormat.rgba8Unorm;
                    break;

                default:
                    img.convertTo(PixelType.rgba8, LAYOUT_GAPLESS | LAYOUT_VERT_STRAIGHT);
                    result.format = TextureFormat.rgba8Unorm;
                    break;
            }

            result.width = img.width();
            result.height = img.height();
            result.data = nu_dup(img.allPixelsAtOnce());
            return result;
        } catch (Exception ex) {
            throw ex;
        }
    }

    /**
        Premultiplies incoming color data.
    */
    void premultiply() {
        final switch (format) {
        case TextureFormat.rgba8Unorm:
            ubyte[] dataView = cast(ubyte[])data;
            foreach (i; 0 .. data.length / 4) {
                size_t offsetPixel = (i * 4);

                float r = (cast(float)dataView[offsetPixel + 0] / 255.0) * (cast(float)dataView[offsetPixel + 3] / 255.0);
                float g = (cast(float)dataView[offsetPixel + 1] / 255.0) * (cast(float)dataView[offsetPixel + 3] / 255.0);
                float b = (cast(float)dataView[offsetPixel + 2] / 255.0) * (cast(float)dataView[offsetPixel + 3] / 255.0);

                dataView[offsetPixel + 0] = cast(ubyte)(r * 255.0);
                dataView[offsetPixel + 1] = cast(ubyte)(g * 255.0);
                dataView[offsetPixel + 2] = cast(ubyte)(b * 255.0);
            }
            return;

        case TextureFormat.none:
        case TextureFormat.r8:
            return;
        }
    }

    /**
        Un-premultiplies incoming color data.
    */
    void unpremultiply() {
        final switch (format) {
        case TextureFormat.rgba8Unorm:
            ubyte[] dataView = cast(ubyte[])data;
            foreach (i; 0 .. data.length / 4) {

                size_t offsetPixel = (i * 4);

                // Ensure no divide by zero happens.
                if (cast(float)dataView[offsetPixel + 3] == 0) {
                    dataView[offsetPixel .. offsetPixel + 3] = 0;
                    continue;
                }

                float r = (cast(float)dataView[offsetPixel + 0] / 255.0) / (cast(float)dataView[offsetPixel + 3] / 255.0);
                float g = (cast(float)dataView[offsetPixel + 1] / 255.0) / (cast(float)dataView[offsetPixel + 3] / 255.0);
                float b = (cast(float)dataView[offsetPixel + 2] / 255.0) / (cast(float)dataView[offsetPixel + 3] / 255.0);
                dataView[offsetPixel + 0] = cast(ubyte)(r * 255.0);
                dataView[offsetPixel + 1] = cast(ubyte)(g * 255.0);
                dataView[offsetPixel + 2] = cast(ubyte)(b * 255.0);
            }
            return;

        case TextureFormat.none:
        case TextureFormat.r8:
            return;
        }
    }

    /**
        Dumps the image data to the specified file.

        Params:
            file = The file to dump the texture data to.
    */
    void dump(string file) {
        if (data.length > 0) {
            Image img;
            img.createView(data.ptr, width, height, format.toPixelType, width*channels);
            img.saveToFile(file);
        }
    }

    /**
        Pads the texture with a 1-pixel wide border.

        Params:
            thickness = The border thickness to generate.
    */
    void pad(uint thickness) {
        if (data.length == 0)
            return;

        uint totalPad = thickness * 2;
        ubyte[] newData = nu_malloca!ubyte((width + totalPad) * (height + totalPad) * channels);
        newData[0 .. $] = 0;

        size_t srcStride = width * channels;
        size_t dstStride = (width + totalPad) * channels;
        foreach (y; 0 .. height) {
            size_t start = (dstStride * (y + thickness)) + (thickness * channels);
            size_t end = start + srcStride;
            newData[start .. end] = cast(ubyte[])data[srcStride * y .. (srcStride * y) + srcStride];
        }

        // Update the texture
        nu_freea(data);
        this.data = newData;
        this.width = width + totalPad;
        this.height = height + totalPad;
    }

    /**
        Resizes the texture data, ensuring that if any data is supplied
        it is updated to fit within the new target size.
    */
    void resize(uint width, uint height) {
        if (data.length > 0) {
            void[] newData = nu_malloca!ubyte(width * height * channels);

            // Copy as many horizontal lines as requested
            // into our new buffer.
            size_t oldStride = this.width * channels;
            size_t newStride = width * channels;
            size_t cStride = min(oldStride, newStride);
            foreach (y; 0 .. min(this.height, height)) {
                newData[newStride * y .. (newStride * y) + newStride] = data[oldStride * y .. (oldStride * y) + cStride];
            }

            // Data has been copied over, now replace the old array.
            nu_freea(data);
            data = newData;
        }

        this.width = width;
        this.height = height;
    }

    /**
        Flip the texture vertically.
    */
    void vflip() {
        if (data.length > 0) {
            size_t stride = width * channels;
            void[] tmp = nu_malloca!ubyte(stride);
            foreach (y; 0 .. height / 2) {
                void[] top = data[stride * y .. (stride * y) + stride];
                void[] bottom = data[stride * (height - (y + 1)) .. (stride * (height - (y + 1))) + stride];

                tmp[0 .. stride] = top[0 .. stride];
                top[0 .. stride] = bottom[0 .. stride];
                bottom[0 .. stride] = tmp[0 .. stride];
            }
        }
    }

    /**
        Frees the texture and all the data associated with it.

        This does not free any data that has been transferred to
        the GPU.
    */
    void free() {
        nu_freea(data);
    }
}

/**
    A cache of textures in use by a model.
*/
final
class TextureCache : NuObject {
private:
@nogc:
    Texture[] textures;

public:

    // Destructor
     ~this() {
        foreach (ref texture; textures) {
            texture.release();
        }
        nu_freea(textures);
    }

    /**
        Size of the texture cache in elements.
    */
    @property size_t size() => textures.length;

    /**
        The cached textures.
    */
    @property Texture[] cache() => textures[0 .. $];

    /**
        Adds a texture to the cache, adding a retain count
        to the texture. Texture caches only allow a single
        instance of a texture to be stored within.

        Params:
            texture = The texture to add to the cache.

        Returns:
            The texture slot position of the added texture.
    */
    uint add(Texture texture) {
        ptrdiff_t idx = find(texture);
        if (idx == -1) {
            textures = textures.nu_resize(textures.length + 1);
            textures[$ - 1] = texture;
            texture.retain();

            return cast(uint)(textures.length - 1);
        }
        return cast(uint)idx;
    }

    /**
        Prunes all textures from the cache, only leaving behind
        textures referenced from outside of the cache.

        Any texture that is unused will be freed.
    */
    void prune() {
        size_t alive = 0;
        foreach (i; 0 .. textures.length) {
            if (auto tex = textures[i].released()) {

                // Avoid copy semantics, moving the alive texture
                // back to the lowest slot now available.
                // Then restore its refcount held by the cache.
                (cast(void*[])textures)[alive++] = cast(void*)tex;
                tex.retain();
            }
        }
        textures = textures.nu_resize(alive);
    }

    /**
        Tries to get a texture from the cache.

        Params:
            slotId = The texture slot ID to try to fetch.
        
        Returns:
            The given texture if found, $(D null) otherwise.
    */
    Texture get(uint slotId) {
        return slotId >= size ? null : textures[slotId];
    }

    /**
        Finds the slot of a given texture within the cache.

        Params:
            texture = The texture to look for.
        
        Returns:
            A non-negative number on success,
            $(D -1) if the texture was not found.
    */
    ptrdiff_t find(Texture texture) {
        foreach (i; 0 .. textures.length) {
            if (textures[i] is texture)
                return i;
        }
        return -1;
    }
}

/**
    Converts a Inochi2D TextureFormat to a Gamut PixelType.

    Params:
        format = The texture format

    Returns:
        The equivalent pixel type.    
*/
PixelType toPixelType(TextureFormat format) @nogc nothrow pure {
    final switch(format) {
        case TextureFormat.none:        return PixelType.unknown;
        case TextureFormat.r8:          return PixelType.l8;
        case TextureFormat.rgba8Unorm:  return PixelType.rgba8;
    }
}