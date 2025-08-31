/**
    Inochi2D Renderer Interface

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.render;
import nulib;
import numem;

public import inochi2d.core.render.buffer;
public import inochi2d.core.render.texture;
public import inochi2d.core.render.resource;

/**
    Resource cache for an owning object.
*/
final
class ResourceCache : NuRefCounted {
private:
@nogc:
    vector!Resource resources_;

public:
    
    /**
        The active resources in the cache for this frame.
    */
    @property Resource[] resources() => resources_[];

    /**
        Creates a new buffer with the given length and usage.

        Params:
            length =    The length of the buffer.
            usage =     The usage of the buffer.
    
        Returns:
            A new buffer.
    */
    Buffer createBuffer(uint length, BufferUsage usage) {
        auto result = nogc_new!Buffer(length, usage);
    
        resources_ ~= result;
        return result;
    }

    /**
        Creates a new texture with the given data.

        Params:
            data = The (compressed) texture file.

        Returns:
            A new texture.
    */
    Texture createTextureFromFile(ubyte[] data) {
        import nulib.io.stream.memstream : MemoryStream;

        MemoryStream mstream = nogc_new!MemoryStream(data);
        auto result = Texture.createForData(TextureData.load(mstream));
        resources_ ~= result;
        return result;
    }

    /**
        Creates a new texture of the given size.

        Params:
            width = The requested width of the texture.
            height = The requested height of the texture.
            format = The requested format of the texture.

        Returns:
            A new texture.
    */
    Texture createTexture(uint width, uint height, TextureFormat format) {
        
        auto result = Texture.create(width, height, format);
        resources_ ~= cast(Resource)result;
        return result;
    }

    /**
        Finalizes a frame for the resource cache,
        this will in turn clean up all risidual requests made.
    */
    void finalize() {
        foreach_reverse(i; 0..resources_.length) {
            resources_[i].finalize();

            if (resources_[i].id is null && resources_[i].status == ResourceStatus.wantsDeletion)
                resources_.removeAt(i);
        }
    }
}