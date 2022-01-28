/*
    Inochi2D Part Mesh Data
    
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.meshdata;
import inochi2d.math;
import inochi2d.core.texture;
import inochi2d.fmt.serialize;

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
    @Optional
    vec2[] uvs;

    /**
        Start coordinate of UVs
    */
    @Optional
    vec2 uvStart;
    
    /**
        End coordinate of UVs
    */
    @Optional
    vec2 uvEnd;

    /**
        Indices in the mesh
    */
    ushort[] indices;

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
        foreach(i; 0..indices.length/3) {
            bool cw = cross(vec3(vertices[i+1]-vertices[i], 0), vec3(vertices[i+2]-vertices[i], 0)).z < 0;

            // Swap winding
            if (cw) {
                vec2 swap = vertices[i+1];
                vertices[i+1] = vertices[i+2];
                vertices[i+2] = swap;
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

        newData.uvStart = uvStart;
        newData.uvEnd = uvEnd;

        return newData;
    }

    void serialize(S)(ref S serializer) {
        auto state = serializer.objectBegin();
            serializer.putKey("verts");
            auto arr = serializer.arrayBegin();
                foreach(vertex; vertices) {
                    serializer.elemBegin;
                    serializer.serializeValue(vertex.x);
                    serializer.elemBegin;
                    serializer.serializeValue(vertex.y);
                }
            serializer.arrayEnd(arr);

            if (uvs.length > 0) {
                serializer.putKey("uvs");
                arr = serializer.arrayBegin();
                    foreach(uv; uvs) {
                        serializer.elemBegin;
                        serializer.serializeValue(uv.x);
                        serializer.elemBegin;
                        serializer.serializeValue(uv.y);
                    }
                serializer.arrayEnd(arr);
            }

            if (uvStart.isFinite) {
                serializer.putKey("uvStart");
                arr = serializer.arrayBegin();
                    serializer.elemBegin;
                    serializer.serializeValue(uvStart.x);
                    serializer.elemBegin;
                    serializer.serializeValue(uvStart.y);
                serializer.arrayEnd(arr);
            }

            if (uvEnd.isFinite) {
                serializer.putKey("uvEnd");
                arr = serializer.arrayBegin();
                    serializer.elemBegin;
                    serializer.serializeValue(uvEnd.x);
                    serializer.elemBegin;
                    serializer.serializeValue(uvEnd.y);
                serializer.arrayEnd(arr);
            }

            serializer.putKey("indices");
            serializer.serializeValue(indices);
        serializer.objectEnd(state);
    }

    SerdeException deserializeFromAsdf(Asdf data) {
        import std.stdio : writeln;
        import std.algorithm.searching: count;
        if (data.isEmpty) return null;

        auto elements = data["verts"].byElement;
        while(!elements.empty) {
            float x;
            float y;
            elements.front.deserializeValue(x);
            elements.popFront;
            elements.front.deserializeValue(y);
            elements.popFront;
            vertices ~= vec2(x, y);
        }

        if (!data["uvs"].isEmpty) {
            elements = data["uvs"].byElement;
            while(!elements.empty) {
                float x;
                float y;
                elements.front.deserializeValue(x);
                elements.popFront;
                elements.front.deserializeValue(y);
                elements.popFront;
                uvs ~= vec2(x, y);
            }
        }
        if (!data["uvStart"].isEmpty) {
            elements = data["uvs"].byElement;
            elements.front.deserializeValue(uvStart.x);
            elements.popFront;
            elements.front.deserializeValue(uvStart.y);
            elements.popFront;

        }

        foreach(indiceData; data["indices"].byElement) {
            ushort indice;
            indiceData.deserializeValue(indice);
            
            indices ~= indice;
        }
        return null;
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
            foreach(x; 0..cuts.x+1) {
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

    void dbg() {
        import std.stdio : writefln;
        writefln("%s %s %s", vertices.length, uvs.length, indices.length);
    }
}