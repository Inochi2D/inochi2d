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
        Generates a quad based mesh which is subdivided `subdiv` amount of times
    */
    static MeshData createQuadMesh(int width, int height, int subdiv = 6) {
        
        // Splits may not be below 2.
        if (subdiv < 2) subdiv = 2;

        MeshData data;
        ushort[int[2]] m;
        int sw = width/subdiv;
        int sh = height/subdiv;
        float uvi = 1f/cast(float)subdiv;

        // Generate points and UVs
        foreach(y; 0..subdiv+1) {
            foreach(x; 0..subdiv+1) {
                data.points ~= vec2(x*sw, y*sh);
                data.uvs ~= vec2(cast(float)x*uvi, cast(float)y*uvi);
                m[[x, y]] = cast(ushort)(data.points.length-1); 
            }	
        }

        // Top left corner
        {
            int[2] indice0 = [0, 0];
            int[2] indice1 = [0, 1];
            int[2] indice2 = [1, 0];
            int[2] indice3 = [1, 1];
            data.indices ~= [
                m[indice0],
                m[indice2],
                m[indice3],
                m[indice0],
                m[indice3],
                m[indice1],
            ];
        }

        // Generate indices
        foreach(y; 0..subdiv) {
            foreach(x; 0..subdiv) {

                // Skip corners, they are special edge cases
                if ((x == 0 && y == 0) || (x == subdiv-1 && y == subdiv-1)) continue;

                // Indices
                int[2] indice0 = [x, y];
                int[2] indice1 = [x, y+1];
                int[2] indice2 = [x+1, y];
                int[2] indice3 = [x+1, y+1];
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

        // Bottom right corner
        {
            int[2] indice0 = [subdiv-1, subdiv-1];
            int[2] indice1 = [subdiv-1, subdiv];
            int[2] indice2 = [subdiv, subdiv-1];
            int[2] indice3 = [subdiv, subdiv];
            data.indices ~= [
                m[indice0],
                m[indice2],
                m[indice3],
                m[indice0],
                m[indice3],
                m[indice1],
            ];
        }

        return data;
    }
}