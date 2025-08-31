/*
    Inochi2D Part Mesh Data
    
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.meshdata;
import inochi2d.core.math;
import inochi2d.core.render;
import inochi2d.core.format;
import std.sumtype;

/**
    Mesh data
*/
struct MeshData {
    /**
        Vertices in the mesh
    */
    vec2[] vertices;

    /**
        Base uvs
    */
    vec2[] uvs;

    /**
        Indices in the mesh
    */
    ushort[] indices;

    /**
        Origin of the mesh
    */
    vec2 origin = vec2(0, 0);

    float[][] gridAxes;

    /**
        Adds a new vertex
    */
    void add(vec2 vertex, vec2 uv) {
        vertices ~= vertex;
        uvs ~= uv;
    }

    /**
        Clear connections/indices
    */
    void clearConnections() {
        indices.length = 0;
    }

    /**
        Connects 2 vertices together
    */
    void connect(ushort first, ushort second) {
        indices ~= [first, second];
    }

    /**
        Find the index of a vertex
    */
    int find(vec2 vert) {
        foreach(idx, v; vertices) {
            if (v == vert) return cast(int)idx;
        }
        return -1;
    }

    /**
        Whether the mesh data is ready to be used
    */
    bool isReady() {
        return indices.length != 0 && indices.length % 3 == 0;
    }

    /**
        Whether the mesh data is ready to be triangulated
    */
    bool canTriangulate() {
        return indices.length != 0 && indices.length % 3 == 0;
    }

    /**
        Fixes the winding order of a mesh.
    */
    void fixWinding() {
        if (!isReady) return;
        
        foreach(j; 0..indices.length/3) {
            size_t i = j*3;

            vec2 vertA = vertices[indices[i+0]];
            vec2 vertB = vertices[indices[i+1]];
            vec2 vertC = vertices[indices[i+2]];
            bool cw = cross(vec3(vertB-vertA, 0), vec3(vertC-vertA, 0)).z < 0;

            // Swap winding
            if (cw) {
                ushort swap = indices[i+1];
                indices[i+1] = indices[i+2];
                indices[i+2] = swap;   
            }
        }
    }

    /**
        Gets connections at a certain point
    */
    int connectionsAtPoint(vec2 point) {
        int p = find(point);
        if (p == -1) return 0;
        return connectionsAtPoint(cast(ushort)p);
    }

    /**
        Gets connections at a certain point
    */
    int connectionsAtPoint(ushort point) {
        int found = 0;
        foreach(index; indices) {
            if (index == point) found++;
        }
        return found;
    }

    MeshData copy() {
        MeshData newData;

        // Copy verts
        newData.vertices.length = vertices.length;
        newData.vertices[] = vertices[];

        // Copy UVs
        newData.uvs.length = uvs.length;
        newData.uvs[] = uvs[];

        // Copy UVs
        newData.indices.length = indices.length;
        newData.indices[] = indices[];

        // Copy axes
        newData.gridAxes = gridAxes[];

        newData.origin = vec2(origin.x, origin.y);

        return newData;
    }

    void onSerialize(ref JSONValue object) {
        object["origin"] = origin.serialize();
        object["verts"] = vertices.serialize();
        object["uvs"] = uvs.serialize();
        object["indices"] = indices.serialize();
        object["grid_axes"] = gridAxes.serialize();
    }

    void onDeserialize(ref JSONValue object) {
        
        if (object.isNull) 
            return;

        object.tryGetRef(origin, "origin");
        object.tryGetRef(vertices, "verts");
        object.tryGetRef(uvs, "uvs");
        object.tryGetRef(indices, "indices");
        object.tryGetRef(gridAxes, "grid_axes");
    }


    /**
        Generates a quad based mesh which is cut `cuts` amount of times

        vec2i size - size of the mesh
        uvBounds - x, y UV coordinates + width/height in UV coordinate space
        cuts - how many time to cut the mesh on the X and Y axis

        Example:
                                Size of Texture                       Uses all of UV    width > height
        MeshData.createQuadMesh(vec2i(texture.width, texture.height), vec4(0, 0, 1, 1), vec2i(32, 16))
    */
    static MeshData createQuadMesh(vec2i size, vec4 uvBounds, vec2i cuts = vec2i(6, 6), vec2i origin = vec2i(0)) {
        
        // Splits may not be below 2.
        if (cuts.x < 2) cuts.x = 2;
        if (cuts.y < 2) cuts.y = 2;

        MeshData data;
        ushort[int[2]] m;
        int sw = size.x/cuts.x;
        int sh = size.y/cuts.y;
        float uvx = uvBounds.w/cast(float)cuts.x;
        float uvy = uvBounds.z/cast(float)cuts.y;

        // Generate vertices and UVs
        foreach(y; 0..cuts.y+1) {
            data.gridAxes[0] ~= y*sh - origin.y;
            foreach(x; 0..cuts.x+1) {
                data.gridAxes[1] ~= x*sw - origin.x;
                data.vertices ~= vec2(
                    (x*sw)-origin.x, 
                    (y*sh)-origin.y
                );
                data.uvs ~= vec2(
                    uvBounds.x+cast(float)x*uvx, 
                    uvBounds.y+cast(float)y*uvy
                );
                m[[x, y]] = cast(ushort)(data.vertices.length-1); 
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

    bool isGrid() {
        return gridAxes.length == 2 && gridAxes[0].length > 2 && gridAxes[1].length > 2;
    }

    bool clearGridIsDirty() {
        if (gridAxes.length < 2 || gridAxes[0].length == 0 || gridAxes[1].length == 0)
            return false;

        bool clearGrid() {
            gridAxes[0].length = 0;
            gridAxes[1].length = 0;
            return true;
        }

        if (vertices.length != gridAxes[0].length * gridAxes[1].length) {
            return clearGrid();
        }

        int index = 0;
        foreach (y; gridAxes[0]) {
            foreach (x; gridAxes[1]) {
                vec2 vert = vec2(x, y);
                if (vert != vertices[index]) {
                    return clearGrid();
                }
                index += 1;
            }
        }
        return false;
    }

    bool regenerateGrid() {
        if (gridAxes[0].length < 2 || gridAxes[1].length < 2)
            return false;

        vertices.length = 0;
        uvs.length = 0;
        indices.length = 0;

        ushort[int[2]] m;

        float minY = gridAxes[0][0], maxY = gridAxes[0][$-1];
        float minX = gridAxes[1][0], maxX = gridAxes[1][$-1];
        float width = maxY - minY;
        float height = maxX - minX;
        foreach (i, y; gridAxes[0]) {
            foreach (j, x; gridAxes[1]) {
                vertices ~= vec2(x, y);
                uvs ~= vec2((x - minX) / width, (y - minY) / height);
                m[[cast(int)j, cast(int)i]] = cast(ushort)(vertices.length - 1);
            }
        }

        vec2 center = vec2(minX + width / 2, minY + height / 2);
        foreach(i; 0..gridAxes[0].length - 1) {
            auto yValue = gridAxes[0][i];
            foreach(j; 0..gridAxes[1].length - 1) {

                auto xValue = gridAxes[1][j];
                int x = cast(int)j, y = cast(int)i;

                // Indices
                int[2] indice0 = [x  , y  ];
                int[2] indice1 = [x  , y+1];
                int[2] indice2 = [x+1, y  ];
                int[2] indice3 = [x+1, y+1];

                // We want the verticies to generate in an X pattern so that we won't have too many distortion problems
                if ((xValue < center.x && yValue < center.y) || (xValue >= center.x && yValue >= center.y)) {
                    indices ~= [
                        m[indice0],
                        m[indice2],
                        m[indice3],
                        m[indice0],
                        m[indice3],
                        m[indice1],
                    ];
                } else {
                    indices ~= [
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
        return true;
    }
}