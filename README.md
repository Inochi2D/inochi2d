<p align="center">
  <img width="256" height="256" src="logo.png">
</p>

# Inochi2D
[![Support me on Patreon](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fshieldsio-patreon.vercel.app%2Fapi%3Fusername%3Dclipsey%26type%3Dpatrons&style=for-the-badge)](https://patreon.com/clipsey)

Inochi2D is a library for realtime 2D puppet animation and the reference implementation of the Inochi2D Puppet standard.

**Currently this library and the standard is in the prototype stage and is not recommended for production use.**  
If you want to try it out anyways you can clone this repo and run `dub add-local (inochi2d folder) "1.0.0"` then manually add it as a dependency in to dub.sdl/json.

&nbsp;

https://user-images.githubusercontent.com/7032834/131196598-d8dee8a7-0c8c-455d-9cea-32183d459b44.mp4

*Early prototype video*

&nbsp;

# Rigging
If you're a model rigger you may want to check out [Inochi Creator](https://github.com/Inochi2D/inochi-creator), the official Inochi2D rigging app in development.  
This repository is purely for the standard and is not useful if you're an end user.

&nbsp;

# Supported platforms
The reference library requires at least OpenGL 4.2 or above, as well support for the SPIR-V ARB extension for per-part shaders.  
*Inochi2D will disable custom shaders if SPIR-V is not found.* 

Implementors are free to implement Inochi2D over other graphics APIs and abstractions and should work on most modern graphics APIs (newer than OpenGL 2)

An official Unity implementation will be provided once 1.0 is complete.

&nbsp;

# How does Inochi2D work?

Inochi2D contains all your parts (textures) in a tree of Node objects.  
Nodes have their own individual purpose.

### Parts
Parts contain the actual textures and vertex information of your model.  
Each part is an individual texture and set of vertices.

### PathDeforms
PathDeforms deform its child Drawables based on its handles.  
PathDeforms can deform multiple Drawables at once.

### Masks
Masks are a Drawable which allow you to specify a shape.  
That shape is used to mask Parts without being a texture itself.

&nbsp;  
*More Node types to come...*

### Do Note
_The spec is still work in progress and is subject to change.  
More details will be revealed once 1.0 of the spec is released._

&nbsp;

# Bootstrapping Inochi2D

Bootstrapping Inochi2D depends on the backing window managment library you are using.

Inochi2D can be boostrapped in GLFW (bindbc) with the following code
```d
// Loads GLFW
loadGLFW();
glfwInit();

// Create Window and initialize OpenGL 4.2 with compat profile
glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_COMPAT_PROFILE);
glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
window = glfwCreateWindow(1024, 1024, "Inochi2D App".toStringz, null, null);

// Make OpenGL current and load its functions.
glfwMakeContextCurrent(window);
loadOpenGL();

// A timing function that returns the current applications runtime in seconds and milliseconds is needed
inInit(cast(double function())glfwGetTime);

// Get the viewport size, which is the size of the scene
int sceneWidth, sceneHeight;

// It is highly recommended to change the viewport with
// inSetViewport to match the viewport you want, otherwise it'll be 640x480
inSetViewport(1024, 1024);
inGetViewport(sceneWidth, sceneHeight);

// Also many vtuber textures are pretty big so let's zoom out a bit.
inGetCamera().scale = vec2(0.5);

// NOTE: If you want to implement camera switching (for eg camera presets) use
// inSetCamera

// NOTE: Loading API WIP, subject to change
Puppet myPuppet = inLoadPuppet("myPuppet.inp");

while(!glfwWindowShouldClose(window)) {
    // NOTE: Inochi2D does not itself clear the main framebuffer
    // you have to do that your self.
    glClear(GL_COLOR_BUFFER_BIT);

    // Run inUpdate first
    // This updates various submodules and time managment for animation
    inUpdate();

    // Imagine there's a lot of rendering code here
    // Maybe even some game logic or something

    // Begins drawing in to the Inochi2D scene
    // NOTE: You *need* to do this otherwise rendering may break
    inBeginScene();

        // Draw and update myPuppet.
        // Convention for using Inochi2D in D is to put everything
        // in a scene block one indent in.
        myPuppet.update();
        myPuppet.draw();

    // Ends drawing in to the Inochi2D scene.
    inEndScene();

    // Draw the scene, background is transparent
    inSceneDraw(vec4i(0, 0, sceneWidth, sceneHeight));

    // Do the buffer swapping and event polling last
    glfwSwapBuffers(window);
    glfwPollEvents();
}
```

### NOTE
The version on dub is not always up to date with the newest features, to use inochi2d from the repo either:
 * Add `~master` as your version in your `dub.selections.json` file after having added inochi2d as a dependency.
 * Clone this repo and run `dub add-local (inochi2d folder) "1.0.0"` to add inochi2d as a local package. You can then add `inochi2d` as a dependency.

&nbsp;

---

The Inochi2D logo was designed by [James Daniel](https://twitter.com/rakujira)
