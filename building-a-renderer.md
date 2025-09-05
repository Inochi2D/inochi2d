# Building an Inochi2D Renderer

Inochi2D has transitioned over to becoming a renderer agonstic API, this means that you will have to supply a renderer yourself that appropriately handles state information sent by Inochi2D in the form of *Draw Lists*.

Note, this will eventually be moved to the official documentation page, this is a preliminary document that will get expanded on as the drawlist system gets improvements.

## Anatomy of a Draw List

A drawlist is a buffer that during an Inochi2D render pass, collects mesh data, state changes, texture sources and uniform data.

This data is sent to you through a series of `DrawCmd` instances.

```d
struct DrawCmd {
    Texture[8] sources;
    uint32_t state;
    float opacity;
    uint32_t blendMode;
    uint32_t maskMode;
    uint32_t vtxOffset;
    uint32_t idxOffset;
    uint32_t elemCount;
}
```

Inochi2D is capable of providing these draw lists with the assumption that your renderer supports index/element data, and optionally, vertex offsets. If your API does not support vertex offsets, set `useBaseVertex` in the Draw List to `false`.

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