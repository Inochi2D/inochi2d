<p align="center">
  <img width="256" height="256" src="https://raw.githubusercontent.com/Inochi2D/branding/main/logo/logo_transparent_256.png">
</p>

_The Inochi2D logo was designed by [James Daniel](https://twitter.com/rakujira)_

# Inochi2D
[![Support me on Patreon](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fshieldsio-patreon.vercel.app%2Fapi%3Fusername%3Dclipsey%26type%3Dpatrons&style=for-the-badge)](https://patreon.com/clipsey)
[![Discord](https://img.shields.io/discord/855173611409506334?label=Community&logo=discord&logoColor=FFFFFF&style=for-the-badge)](https://discord.com/invite/abnxwN6r9v)  
[日本語](https://github.com/Inochi2D/inochi2d/blob/main/README.ja.md) |
[简体中文](https://github.com/Inochi2D/inochi2d/blob/main/README.zh.md)

---

Inochi2D is a library for realtime 2D puppet animation and the reference implementation of the Inochi2D Puppet standard. Inochi2D works by deforming 2D meshes created from layered art at runtime based on parameters, this deformation tricks the viewer in to seeing 3D depth and movement in the 2D art.

&nbsp;

<iframe width="560" height="315" src="https://www.youtube.com/embed/4TWIa5gdcxw?si=SJhLlPYR2O00fOWT" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

&nbsp;

# For Riggers and VTubers
If you're a model rigger you may want to check out [Inochi Creator](https://github.com/Inochi2D/inochi-creator), the official Inochi2D rigging app in development.
If you're a VTuber you may want to check out [Inochi Session](https://github.com/Inochi2D/inochi-session).
This repository is purely for the standard and is not useful if you're an end user.

&nbsp;

# System Requirements

| Hardware | Requirement                                   |
| -------: | :-------------------------------------------- |
|      CPU | x86-64 CPU with SSE4+, Aarch64 with NEON.     |
|   Memory | At least 1 GB of RAM for bigger models.       |
|      GPU | Depends on renderer backend.                  |

Inochi2D has no dependencies on non-D libraries besides a POSIX compliant C standard library.  
Do note that until the transition to `nogc` is complete, you'll have the best experience with
`glibc` on UNIX-like platforms.

SSE and NEON optimisations are only enabled in `release` and `release-debug` builds.

&nbsp;

# Official SDK Bindings
 - [Unity](https://github.com/Inochi2D/com.inochi2d.inochi2d-unity)

&nbsp;

# Using the Inochi2D SDK

Inochi2D can both be used in and outside of DLang, to use Inochi2D in your D project just add it from dub.  
To use Inochi2D within a project written in another language, a C FFI is provided.

To compile using the C FFI you must have the `LDC2` compiler installed and the `dub` build system,
run the following command to build the SDK:
```
dub build --config=dynamic
```

If your target graphics library does not allow 2D vectors to be used when passing position data
to the GPU, you can add `--d-version=IN_VEC3_POSITION` as an argument, which will change the 
VtxData to use a 3D vector to store the vertex position.

You can alternatively download precompiled versions of the SDK from the [Releases](https://github.com/Inochi2D/inochi2d/releases).

## Build Configurations
Add with `--config=`

|          Type | Use                                    |
| ------------: | :------------------------------------- |
|      `static` | Static D-only library.                 |
| `static-nurt` | Static D-only nogc-only library.       |
|     `dynamic` | Dynamic library with C FFI.            |
|        `wasm` | WebAssembly module, wasm-sdk required. |
|    `unittest` | Unit test runner                       |

## Build Types
Add with `--build=`

You can pass the following build types to Inochi2D.
|            Type | Use                                            |
| --------------: | :--------------------------------------------- |
|         `debug` | Debug mode, no optimisation, full stacktraces. |
| `release-debug` | Optimized build with some stack traces.        |
|       `release` | Full release build.                            |

## Build Options
Add with `--d-version=`

|             Option | Use                                                                |
| -----------------: | :----------------------------------------------------------------- |
| `IN_VEC3_POSITION` | Use 3D vectors to store the `POSITION` portion of the vertex data. |
|     `IN_NO_LEGACY` | Disables legacy features.                                          |

## D
To use Inochi2D from D, simply add it as a package to your dub file.

## C, C++, Rust, etc.
To use Inochi2D from C, C++, Rust, etc. build the SDK with the `dynamic` configuration.

A C header will be copied to the out directory, said header can be found in `include/`.

Note that if you're writing your own bindings that Inochi2D uses the `cdecl` 
calling convention on **all** platforms.

## WebAssembly
Inochi2D may be used on the web via WebAssembly, currently this requires a patched `druntime` source 
tree, which can be installed (Linux-only) from the releases at https://github.com/Inochi2D/sdk-toolchain.

Alternatively, pre-compiled release and debug versions of the SDK are available in our nightly releases,
and starting with 0.9, our main releases.

You can find javascript wrappers, etc. in `dist/`.

## Godot
We provide an official binding for Godot, using GDExtension and the `nugodot` bindings.
To build it you **must** either have your target version of Godot in your `PATH` environment variable,
or specify the full path to godot with the `GODOT_PATH` environment variable.

The GDExtension may then be built by running `dub build :godot` in the root of this repository,
the GDExtension will be written to `modules/godot/out/`. Move the contents of this folder into your
Godot project under a subfolder called `inochi2d`, then reload your Project.

You should then be able to load in `inx` and `inp` model files.

## Examples

You may find examples in the `examples/` directory.

# Inochi2D Technical Documentation
Technical documentation for Inochi2D is provided in the `tech-docs/` directory, 
these are shipped with the SDK.