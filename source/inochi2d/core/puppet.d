/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.puppet;
import inochi2d.core.mesh;

/**
    TopLevel Mesh
*/
struct TLMesh {
    
    /**
        value from -1 to 1 which determines sort order

        Sorting is done from back to front, -1 is in back, 1 is in front
    */
    float z;

    /**
        Reference to the mesh itself
    */
    DynMesh mesh;
}

class Puppet {
    TLMesh[] meshes;
}