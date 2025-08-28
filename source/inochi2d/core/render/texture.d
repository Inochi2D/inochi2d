/**
    Inochi2D Textures

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.render.texture;
import nulib.io.stream;
import inmath;
import numem;

/**
    Filtering mode for texture
*/
enum Filtering {
    
    /**
        Linear filtering will try to smooth out textures
    */
    linear,

    /**
        Point filtering will try to preserve pixel edges.
        Due to texture sampling being float based this is imprecise.
    */
    point
}

/**
    Current status of a texture
*/
enum TextureStatus : int {

    /**
        No active request for the given texture.
    */
    ok = 0,
    
    /**
        A new texture is requested to be created and passed
        to the Inochi2D rendering engine.
    */
    wantsCreate = 1,
    
    /**
        A texture is requested to be updated, either in contents,
        or in overall dimensions.
    */
    wantsUpdates = 2,
    
    /**
        A texture is requested to be deleted.
    */
    wantsDeletion = 3
}

/**
    Format of texture data.
*/
enum InTextureFormat : uint {

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
class Texture : NuRefCounted {
public:
@nogc:

    /**
        Creates a new texture.

        Params:
            width = The requested width of the texture,
            height = The requested height of the texture,
            format = The requested format of the texture,
    */
    static Texture create(uint width, uint height, InTextureFormat format) {
        return nogc_new!Texture(width, height, format);
    }

    /**
        Creates a new texture with the given texture data.

        Params:
            data = The data to use for creation.
    */
    static Texture createForData(TextureData data) {
        Texture tex = Texture.create(data.size.x, data.size.y, data.format);
        tex.updates = nu_malloca!TextureData(1);
        tex.updates[0] = data;
        return tex;
    }

    /**
        Constructs a new texture.
    */
    this(uint width, uint height, InTextureFormat format) {
        this.width = width;
        this.height = height;
        this.format = format;
        this.status = TextureStatus.wantsCreate;
    }

    /**
        Current status of the texture
    */
    TextureStatus status;

    /**
        Format of the texture.
    */
    InTextureFormat format;

    /**
        Width of the texture in pixels.
    */
    uint width;
    
    /**
        Height of the texture in pixels.
    */
    uint height;
    
    /**
        Platform ID of the texture.
    */
    void* id;

    /**
        Updates to texture.
    */
    TextureData[] updates;

    /**
        Enqueues an update to the texture.
    */
    void update(TextureData data) {
        this.status = TextureStatus.wantsUpdates;
        this.updates = updates.nu_resize(updates.length+1);
        this.updates[$-1] = data;
    }

    /**
        Marks all requested texture updates as finalized.
    */
    void finalize() {
        this.status = TextureStatus.ok;
        
        /// First free all the texture data associated
        /// with the updates, then clear the updates array.
        foreach(ref update; updates)
            update.free();
        
        nu_freea(updates);
    }
}

/**
    Texture Data used during GPU uploads.
*/
struct TextureData {
public:
@nogc:
    InTextureFormat format;
    vec2i position;
    vec2i size;
    void[] data;

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

            IFInfo info = read_info(tmpbuffer);
            enforce(info.e, IF_ERROR[info.e]);

            result.size.x = info.w;
            result.size.y = info.h;

            // Only read RGBA8 or R8 data.
            IFImage img = read_image(tmpbuffer, info.c == 1 ? 1 : 4, 8);
            result.data = cast(void[])img.buf8;
            result.format = info.c == 1 ? InTextureFormat.r8 : InTextureFormat.rgba8Unorm;

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
            case InTextureFormat.rgba8Unorm:
                ubyte[] dataView = cast(ubyte[])data;
                foreach(i; 0..data.length/4) {

                    size_t offsetPixel = (i*4);
                    dataView[offsetPixel+0] = cast(ubyte)((cast(int)dataView[offsetPixel+0] * cast(int)dataView[offsetPixel+3])/255);
                    dataView[offsetPixel+1] = cast(ubyte)((cast(int)dataView[offsetPixel+1] * cast(int)dataView[offsetPixel+3])/255);
                    dataView[offsetPixel+2] = cast(ubyte)((cast(int)dataView[offsetPixel+2] * cast(int)dataView[offsetPixel+3])/255);
                }
                return;
            
            case InTextureFormat.none:
            case InTextureFormat.r8:
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
        this.format = InTextureFormat.none;
        this.size = vec2i.init;
        this.position = vec2i.init;
        nu_freea(data);
    }
}