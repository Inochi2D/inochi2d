<p align="center">
  <img width="256" height="256" src="https://raw.githubusercontent.com/Inochi2D/branding/main/logo/logo_transparent_256.png">
</p>

[日本語](https://github.com/Inochi2D/inochi2d/blob/main/README.ja.md)
[简体中文](https://github.com/Inochi2D/inochi2d/blob/main/README.zh.md)

# Inochi2D
[![Support me on Patreon](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fshieldsio-patreon.vercel.app%2Fapi%3Fusername%3Dclipsey%26type%3Dpatrons&style=for-the-badge)](https://patreon.com/clipsey)
[![Discord](https://img.shields.io/discord/855173611409506334?label=Community&logo=discord&logoColor=FFFFFF&style=for-the-badge)](https://discord.com/invite/abnxwN6r9v)

Inochi2D is a library for realtime 2D puppet animation and the reference implementation of the Inochi2D Puppet standard. Inochi2D works by deforming 2D meshes created from layered art at runtime based on parameters, this deformation tricks the viewer in to seeing 3D depth and movement in the 2D art.

&nbsp;


https://user-images.githubusercontent.com/7032834/166389697-02eeeedb-6a44-4570-9254-f6aa4f095300.mp4

*Video from Beta 0.7.2, [LunaFoxgirlVT](https://twitter.com/LunaFoxgirlVT), model art by [kpon](https://twitter.com/kawaiipony2)*

&nbsp;

# Looking for 0.8?
Inochi2D is undergoing what essentially amounts to a rewrite, if you're looking for Inochi2D 0.8 check the v0_8 branch!

# For Riggers and VTubers
If you're a model rigger you may want to check out [Inochi Creator](https://github.com/Inochi2D/inochi-creator), the official Inochi2D rigging app in development.
If you're a VTuber you may want to check out [Inochi Session](https://github.com/Inochi2D/inochi-session).
This repository is purely for the standard and is not useful if you're an end user.

&nbsp;

# Documentation
Documentation is currently in the process of being written for the spec and the official tools. You can find the official documentation page [here](https://docs.inochi2d.com).

&nbsp;

# Supported platforms
Inochi2D is a "bring your own renderer" API, we provide a OpenGL 3.1 backend to get you started easily and to work as a reference on how a renderer can be implemented.  
To use the OpenGL renderer call `inRendererInitGL` during initialization of Inochi2D, a OpenGL 3.1 core context needs to be present.

We provide [inochi2d-c](https://github.com/Inochi2D/inochi2d-c) as a way to use this library from non-D languages and we will be providing a layer to allow non-D languages to create rendering backends, additionally a second workgroup is making a pure Rust implementation of the Inochi2D specification over at [Inox2D](https://github.com/Inochi2D/inox2d).

#### NOTE
Inochi2D does not support compilation with the OpenD language. Only the [the official D language](https://dlang.org) and compilers are supported.

&nbsp;


## Special Thanks

This project is funded through [NGI0 Entrust](https://nlnet.nl/entrust), a fund established by [NLnet](https://nlnet.nl) with financial support from the European Commission's [Next Generation Internet](https://ngi.eu) program. Learn more at the [NLnet project page](https://nlnet.nl/project/Inochi2D).

[<img src="https://nlnet.nl/logo/banner.svg" alt="NLnet foundation logo" width="20%" />](https://nlnet.nl)  

---

The Inochi2D logo was designed by [James Daniel](https://twitter.com/rakujira)
