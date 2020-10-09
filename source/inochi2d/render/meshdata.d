/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.render.meshdata;
import inochi2d.math;

/**
    Mesh data
*/
struct MeshData {
    /**
        Points in the mesh
    */
    vec2[] points;

    /**
        UVs in the mesh
    */
    vec2[] uvs;

    /**
        Indices in the mesh
    */
    ushort[] indices;


    /**
        Generates a quad based mesh which is cut `cuts` amount of times

        vec2i size - size of the mesh
        uvBounds - x, y UV coordinates + width/height in UV coordinate space
        cuts - how many time to cut the mesh on the X and Y axis

        Example:
                                Size of Texture                       Uses all of UV    width > height
        MeshData.createQuadMesh(vec2i(texture.width, texture.height), vec4(0, 0, 1, 1), vec2i(32, 16))
    */
    static MeshData createQuadMesh(vec2i size, vec4 uvBounds, vec2i cuts = vec2i(6, 6)) {
        
        // Splits may not be below 2.
        if (cuts.x < 2) cuts.x = 2;
        if (cuts.y < 2) cuts.y = 2;

        MeshData data;
        ushort[int[2]] m;
        int sw = size.x/cuts.x;
        int sh = size.y/cuts.y;
        float uvx = uvBounds.w/cast(float)cuts.x;
        float uvy = uvBounds.z/cast(float)cuts.y;

        // Generate points and UVs
        foreach(y; 0..cuts.y+1) {
            foreach(x; 0..cuts.x+1) {
                data.points ~= vec2(x*sw, y*sh);
                data.uvs ~= vec2(uvBounds.x+cast(float)x*uvx, uvBounds.y+cast(float)y*uvy);
                m[[x, y]] = cast(ushort)(data.points.length-1); 
            }	
        }

        // Generate indices
        vec2i center = vec2i(cuts.x/2, cuts.y/2);
        foreach(y; 0..cuts.y) {
            foreach(x; 0..cuts.x) {

                // Indices
                int[2] indice0 = [x, y];
                int[2] indice1 = [x, y+1];
                int[2] indice2 = [x+1, y];
                int[2] indice3 = [x+1, y+1];

                // We want the verticies to generate in an X pattern so that we won't have too many distortion problems
                if ((x < center.x && y < center.y) || (x >= center.x && y >= center.y)) {
                    data.indices ~= [
                        m[indice0],
                        m[indice2],
                        m[indice3],
                        m[indice0],
                        m[indice3],
                        m[indice1],
                    ];
                } else {
                    data.indices ~= [
                        m[indice0],
                        m[indice1],
                        m[indice2],
                        m[indice1],
                        m[indice2],
                        m[indice3],
                    ];
                }
            }
        }


        return data;
    }
}