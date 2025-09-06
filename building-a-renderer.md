# Building an Inochi2D Renderer

Inochi2D has transitioned over to becoming a renderer agonstic API, this means that you will have to supply a renderer yourself that appropriately handles state information sent by Inochi2D in the form of *Draw Lists*.

Note, this will eventually be moved to the official documentation page, this is a preliminary document that will get expanded on as the drawlist system gets improvements.

## Anatomy of a Draw List

A drawlist is a buffer that during an Inochi2D render pass, collects mesh data, state changes, texture sources and uniform data.

This data is sent to you through a series of `DrawCmd` instances.

```d
struct DrawCmd {
    in_texture_t*[8]    sources;
    in_drawstate_t      state;
    in_blend_mode_t     blendMode;
    in_mask_mode_t      maskMode;
    uint32_t            vtxOffset;
    uint32_t            idxOffset;
    uint                type;
    void[64]            vars;
}
```

Inochi2D is capable of providing these draw lists with the assumption that your renderer supports index/element data, and optionally, vertex offsets. If your API does not support vertex offsets, set `useBaseVertex` in the Draw List to `false`.

### Variables

Some nodes in Inochi2D provide further data needed to render the the node, these are provided in
`vars`, up to 64 bytes of variable space is allocated per draw command. Read the individual Node's
documentation for which variables are stored within. The `type` variable can be used to determine which
node type the data pertains to. 

## DrawState

Inochi2D's rendering pipeline is rather complex, the framework supports masking and multi-layered compositing. As such, `DrawState` supplies flags for you to determine how to handle individual commands.

|   Value    |           Name | Description                                                                         |
| :--------: | -------------: | :---------------------------------------------------------------------------------- |
| 0x00000000 |         normal | Normal drawing should proceed, no masks are enabled.                                |
| 0x00000001 |     defineMask | A mask is being defined, may last multiple commands, fill out your masking buffer.  |
| 0x00000002 |     maskedDraw | The content to be masked is being drawn, multiply color and alpha with the mask.    |
| 0x00000003 | compositeBegin | Begin a new composite, essentially nested framebuffers, should be stored in a stack |
| 0x00000004 |   compositeEnd | End the top level composite.                                                        |
| 0x00000005 |  compositeBlit | The composite should be drawn to the now active framebuffer.                        |

#### Notes
* It is recommended for composites to store a reusable stack/list of framebuffers, every time a composition pass begins you will want to clear the composite's color channels.
* It is recommended for masking to be done by drawing to a `R8Unorm` texture, using the input textures alpha as the drawing color.  
You can then during `maskedDraw` add this texture to your pass, multiply `rgba` with `rrrr` from the mask texture.
* On the transition from `maskedDraw` to `normal`, if you are not using unique shaders for `normal` you may want to clear the mask texture with all `0xFF`.
* `compositeEnd` **may** be followed by `defineMask`, ensure that `compsiteBlit` is able to use the defined mask.
* `compositeBlit` *should* be implemented by drawing a viewport-filling quad, an NDC mesh is provided for you in this DrawState to make it easier.

## Registered Types

Following is a list of all currently registered types, all types have a 32 bit type ID,
with `0x00000000` to `0x0000FFFF` being reserved by Inochi2D.

Following is a table of all the core node types of Inochi2D.

|         ID | Name            |
| ---------: | :-------------- |
| 0x00000000 | Node            |
| 0x00000001 | Drawable        |
| 0x00000101 | Part            |
| 0x00000201 | AnimatedPart    |
| 0x00000002 | Deformer        |
| 0x00000102 | MeshGroup       |
| 0x00000202 | LatticeDeformer |
| 0x00000003 | Driver          |
| 0x00000103 | SimplePhysics   |
| 0x00000004 | Composite       |

All Inochi2D node types follow a numeric ID sequence of `0x0000SSBB` where  
 * `SS` is the subnode id
 * `BB` is the supernode id

Part has ID 0x00000101, as it's type `01` (Part), derived from type `01` (Drawable)