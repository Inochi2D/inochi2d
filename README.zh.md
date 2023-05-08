<p align="center">
  <img width="256" height="256" src="https://raw.githubusercontent.com/Inochi2D/branding/main/logo/logo_transparent_256.png">
</p>

# Inochi2D

在 Patreon 上提供资金支持：
[![Support me on Patreon](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fshieldsio-patreon.vercel.app%2Fapi%3Fusername%3Dclipsey%26type%3Dpatrons&style=for-the-badge)](https://patreon.com/clipsey)
Discord 社区：
[![Discord](https://img.shields.io/discord/855173611409506334?label=Community&logo=discord&logoColor=FFFFFF&style=for-the-badge)](https://discord.com/invite/abnxwN6r9v)

Inochi2D（当前代码仓库）是一个实时二维皮套动画库，也是 Inochi2D 标准的参考实现。Inochi2D 的基本工作原理是，在运行时，根据给定的参数，对绑定在分层美术资源上的2D网格进行变形。这样的变形使得观众可以在二维图形中体验到三维的深度与动画效果。

&nbsp;

https://user-images.githubusercontent.com/7032834/166389697-02eeeedb-6a44-4570-9254-f6aa4f095300.mp4

*来自 Beta 0.7.2 版本的视频，作者 [LunaFoxgirlVT](https://twitter.com/LunaFoxgirlVT), 画师 [kpon](https://twitter.com/kawaiipony2)*

&nbsp;

# 如果您是模型师或虚拟皮套使用者：

模型师可能会感兴趣 [Inochi Creator](https://github.com/Inochi2D/inochi-creator), 这是正在开发中的 Inochi2D 官方建模软件。
虚拟皮套使用者可能会感兴趣 [Inochi Session](https://github.com/Inochi2D/inochi-session)。
当前代码仓库是为了 Inochi2D 标准而存在的，对最终用户可能用处有限。

&nbsp;

# 文档
有关标准和官方工具的文档目前正在编写和翻译过程中。官方文档在[这里](https://docs.inochi2d.com)。

&nbsp;

# 设备支持情况
当前仓库里的实现需要在一个 OpenGL 3.1 Context 中运行。`inInit`函数应当在 OpenGL 3.1 （或更高版本）Context *建立后* 被调用。

我们计划从前端代码中分离出渲染部分，这样开发者们就能接入自己的渲染后端。

我们提供 [inochi2d-c](https://github.com/Inochi2D/inochi2d-c) 作为从非 D 的语言中调用本库的接口。

额外地，另一个开发组正在编写一个 Inochi2D 标准的纯 Rust 实现，代码仓库在[这里](https://github.com/Inochi2D/inox2d)。

&nbsp;


---

Inochi2D 的标志是 [James Daniel](https://twitter.com/rakujira) 设计的。
