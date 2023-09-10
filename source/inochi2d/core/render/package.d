module inochi2d.core.render;
import inochi2d.core.texture;

public import inochi2d.core.render.ftable;

/**
    A render ID

    IDs 0-128 are reserved by Inochi2D for official nodes
*/
alias InRID = uint;

/// Dummy none ID.
enum InRID IN_NONE = 0;

/// A part
enum InRID IN_PART = 1;

/// A animated part
enum InRID IN_ANIMATED_PART = 2;

/// A mask
enum InRID IN_MASK = 3;

/// Beginning of a composite pass
enum InRID IN_COMPOSITE_BEGIN = 10;

/// End of a composite pass
enum InRID IN_COMPOSITE_END = 11;

/// Begin of masking pass
enum InRID IN_MASK_BEGIN = 12;

/// Begin of masking element pass
enum InRID IN_MASK_ELEM = 13;

/// End of masking pass
enum InRID IN_MASK_END = 14;

/**
    A mesh
*/
struct InRenderMesh {

    /// Amount of vertex buffers
    size_t vtxBufferCount;

    /// Vertex buffer IDs
    void** vtxBuffers;

    /// Index/Element buffer ID
    void* indices;
}

/**
    Allocates a mesh object with the specified amount of buffer slots
*/
InRenderMesh inRenderAllocMesh(size_t buffers) {
    void*[] bufs = new void*[buffers];
    return InRenderMesh(
        bufs.length,
        bufs.ptr,
        null
    );
}

/**
    Render data for one RID
*/
struct InRenderData {

    /**
        Pointer to per-node struct of render information

        Is null if the RID does not have any data associated with it.
    */
    void* data;

    /**
        The Mesh object

        Is null if the RID does not render any meshes.
    */
    InRenderMesh* mesh;

    /**
        Reference to the view being rendered to

        Is null if the view should stay as is.

        For OpenGL the view ID is OpenGL render id + 1.
        To reset to main framebuffer set to 1.
    */
    void* viewId;

    /**
        Amount of textures
    */
    size_t texCount;

    /**
        Textures
    */
    RuntimeTexture* textures;
}