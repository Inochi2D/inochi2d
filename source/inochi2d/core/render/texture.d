/**
    Inochi2D Textures

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.render.texture;
import inochi2d.core.render.resource;
import nulib.io.stream;
import inmath;
import numem;

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
    r8 = 2,
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
        final switch(format) {
            case TextureFormat.rgba8Unorm:
                return 4;

            case TextureFormat.r8:
                return 1;

            case TextureFormat.none:
                return 0;
        }
    }

    static TextureData load(ubyte[] data) {
        import nulib.io.stream.memstream : MemoryStream;
        return TextureData.load(nogc_new!MemoryStream(data));
    }

    /**
        Loads a texture from a stream.

        Params:
            stream = The stream to read from.
    */
    static TextureData load(Stream stream) {
        import imagefmt : IFImage, IFInfo, IF_ERROR, read_image, read_info, ERROR;
        ubyte[] tmpbuffer = nu_malloca!ubyte(stream.length);

        TextureData result;
        try {
            enforce(stream.read(tmpbuffer) >= 0, "Failed reading texture data from stream!");
            nogc_delete(stream);

            IFInfo info = read_info(tmpbuffer);
            enforce(info.e == 0, IF_ERROR[info.e]);

            result.width = info.w;
            result.height = info.h;

            // Only read RGBA8 or R8 data.
            IFImage img = read_image(tmpbuffer, info.c == 1 ? 1 : 4, 8);
            result.data = cast(void[])img.buf8;
            result.format = info.c == 1 ? TextureFormat.r8 : TextureFormat.rgba8Unorm;

            return result;
        } catch(Exception ex) {
            nu_freea(tmpbuffer);
            throw ex;
        }
    }

    /**
        Premultiplies incoming color data.
    */
    void premultiply() {
        final switch(format) {
            case TextureFormat.rgba8Unorm:
                ubyte[] dataView = cast(ubyte[])data;
                foreach(i; 0..data.length/4) {

                    size_t offsetPixel = (i*4);
                    dataView[offsetPixel+0] = cast(ubyte)((cast(int)dataView[offsetPixel+0] * cast(int)dataView[offsetPixel+3])/255);
                    dataView[offsetPixel+1] = cast(ubyte)((cast(int)dataView[offsetPixel+1] * cast(int)dataView[offsetPixel+3])/255);
                    dataView[offsetPixel+2] = cast(ubyte)((cast(int)dataView[offsetPixel+2] * cast(int)dataView[offsetPixel+3])/255);
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
        import imagefmt : write_image;
        if (data.length > 0) {
            write_image(file, width, height, cast(ubyte[])data, 4);
        }
    }

    /**
        Resizes the texture data, ensuring that if any data is supplied
        it is updated to fit within the new target size.
    */
    void resize(uint width, uint height) {
        if (data.length > 0) {
            void[] newData = nu_malloca!ubyte(width*height*channels);

            // Copy as many horizontal lines as requested
            // into our new buffer.
            size_t oldStride = this.width*channels;
            size_t newStride = width*channels;
            size_t cStride = min(oldStride, newStride);
            foreach(y; 0..min(this.height, height)) {
                newData[newStride*y..(newStride*y)+newStride] = data[oldStride*y..(oldStride*y)+cStride];
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
            size_t stride = width*channels;
            void[] tmp = nu_malloca!ubyte(stride);
            foreach(y; 0..height/2) {
                void[] top = data[stride*y..(stride*y)+stride];
                void[] bottom = data[stride*(height-(y+1))..(stride*(height-(y+1)))+stride];

                tmp[0..stride] = top[0..stride];
                top[0..stride] = bottom[0..stride];
                bottom[0..stride] = tmp[0..stride];
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
class TextureCache : NuRefCounted {
private:
@nogc:
    Texture[] textures;

public:

    // Destructor
    ~this() {
        foreach(texture; textures) {
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
    @property Texture[] cache() => textures[0..$];

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
            textures = textures.nu_resize(textures.length+1);
            textures[$-1] = texture;
            texture.retain();

            return cast(uint)(textures.length-1);
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
        foreach(i; 0..textures.length) {
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
        if (slotId < size)
            return textures[slotId];
        
        return null;
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
        foreach(i; 0..textures.length) {
            if (textures[i] is texture)
                return i;
        }
        return -1;
    }
}