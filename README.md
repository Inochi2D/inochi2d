<p align="center">
  <img width="256" height="256" src="logo.png">
</p>

# Inochi2D
Inochi2D is a library for realtime 2D puppet animation and the reference implementation of the Inochi2D Puppet standard.

Currently this library and the standard is in the prototype stage and is not recommended for production use.

&nbsp;


https://user-images.githubusercontent.com/7032834/118180826-4c39f600-b437-11eb-99a0-73e325408895.mp4

*Early prototype video*

# Supported platforms
Inochi2D is being developed on Linux but is being made with cross-platform use in mind and thus should work on Windows.

Android and iOS are currently not supported due to the lack of an OpenGL ES backend.

The Inochi2D Puppet standard's only requirement is the hardware and software supporting some form of modern programmable hardware accellerated 3D rendering. (Eg OpenGL, Vulkan, Metal or DirectX)

&nbsp;

# Testing
Currently the testbed used to test and develop Inochi2D in its prototype stage is in `examples/basicrender`.

&nbsp;

# How will Inochi2D work?
Inochi2D will expose an API for loading/saving and manipulating 2D puppets mainly for use in realtime applications.

The Inochi2D Puppet standard exposes all the neccesary mesh, deformation information as well as physics handling information for stuff like hair, joints and the like which Inochi2D uses to generate a realtime puppet which can be manipulated via eg. facial/body tracking and predefined animations.

Inochi2D provides the means to render your puppet to an OpenGL context. Do note that the library does change OpenGL state.

More details will be available as the library develops.

&nbsp;

# How to use
Add the library to your project from the dub database.
```
dub add inochi2d
```

Inochi2D can be boostrapped in GLFW with the following code
```d
// After creating your OpenGL context and making it current...
// A timing function that returns the current applications runtime in seconds and milliseconds is needed
inInit(cast(double function())glfwGetTime);

// Get the viewport size, which is the size of the scene
int sceneWidth, sceneHeight;
inGetViewport(sceneWidth, sceneHeight);

// NOTE: It is highly recommended to change the viewport with
// inSetViewport to match the viewport you want, otherwise it'll be 640x480

// NOTE: If you want to implement camera switching (for eg camera presets) use
// inSetCamera

// NOTE: Loading API WIP, subject to change
Puppet myPuppet = loadPuppet("myPuppet.inp");

while(!glfwWindowShouldClose(window)) {

    // Run updateInochi2D first
    // This updates various submodules and time managment for animation
    inUpdate();

    // Imagine there's a lot of rendering code here
    // Maybe even some game logic or something

    // Draw myPuppet, this will change the framebuffer to an internal framebuffer
    myPuppet.draw();

    // Draw the scene, background is transparent
    inSceneDraw(vec4i(0, 0, sceneWidth, sceneHeight));

    // Do the buffer swapping and event polling last
    glfwSwapBuffers(window);
    glfwPollEvents();
}
```

### NOTE
Currently not in the dub database use `dub add-local (inochi2d folder) "1.0.0"` to add inochi2d as a local package. You can then add `inochi2d` as a dependency as can be seen in `examples/basicrender`

&nbsp;

---

The Inochi2D logo was designed by [James Daniel](https://twitter.com/rakujira)
