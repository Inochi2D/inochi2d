# Inochi2D
Inochi2D is a bring-your-own-renderer library for realtime 2D puppet animation and the reference implementation of the Inochi2D Puppet standard.

Currently this library and the standard is in the prototype stage and is not recommended for production use.

&nbsp;

# Testing
Currently the testbed used to test and develop Inochi2D in its prototype stage is in `examples/basicrender`.

&nbsp;

# How will Inochi2D work?
Inochi2D will expose an API for loading/saving and manipulating 2D puppets mainly for use in realtime applications.

The Inochi2D Puppet standard exposes all the neccesary mesh, deformation information as well as physics handling information for stuff like hair, joints and the like which Inochi2D uses to generate a realtime puppet which can be manipulated via eg. facial/body tracking and predefined animations.

Inochi2D provides all the mesh and UV information that you can then send to eg. OpenGL, Vulkan or DirectX for rendering by setting the rendering hooks present in `inochi2d`.

More details will be available as the library develops.

&nbsp;

# How to use
Add the library to your project from the dub database.
```
dub add inochi2d
```

### NOTE
Currently not in the dub database use `dub add-local (inochi2d folder) "1.0.0"` to add inochi2d as a local package. You can then add `inochi2d` as a dependency as can be seen in `examples/basicrender`