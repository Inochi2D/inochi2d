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
    rgba8Unorm,

    /**
        Red-channel only mask data.
    */
    r8,
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
        Texture tex = Texture.create(data.size.x, data.size.y, data.format);
        tex.data = data;
        return tex;
    }

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
        this.status = ResourceStatus.wantsCreate;
    }

    void resize(uint width, uint height) {
        data.width = width;
        data.height = height;
        this.status = ResourceStatus.wantsUpdates;
    }

    /**
        Marks all requested texture updates as finalized.
    */
    override
    void finalize() {
        this.status = 
            status == ResourceStatus.wantsDeletion ? 
                status : 
                ResourceStatus.ok;
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
            stream.close();

            IFInfo info = read_info(tmpbuffer);
            enforce(info.e, IF_ERROR[info.e]);

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
            write_image(file, size.x, size.y, cast(ubyte[])data, 4);
        }
    }

    /**
        Frees the texture and all the data associated with it.

        This does not free any data that has been transferred to
        the GPU.
    */
    void free() {
        this.format = TextureFormat.none;
        this.width = 0;
        this.height = 0;
        nu_freea(data);
    }
}