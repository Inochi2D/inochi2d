/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.render.dynmesh;
import inochi2d.math;
import inochi2d.render;
import bindbc.opengl;
import std.exception;
import std.algorithm.mutation : copy;

private GLuint vao;
private Shader dynMeshShader;
private Shader dynMeshDbg;
package(inochi2d) {
    void initDynMesh() {
        glGenVertexArrays(1, &vao);
        dynMeshShader = new Shader(import("dynmesh.vert"), import("dynmesh.frag"));
        dynMeshDbg = new Shader(import("dynmesh.vert"), import("dynmesh_dbg.frag"));
    }
}

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
}

/**
    A dynamic deformable textured mesh
*/
class DynMesh {
private:
    Shader shader;
    Texture texture;
    MeshData data;
    GLuint ibo;
    GLuint vbo;
    GLuint uvbo;

    // View-projection matrix uniform location
    GLint mvp;

    // Whether this mesh is marked for an update
    bool marked;

    void setIndices() {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, data.indices.length*ushort.sizeof, data.indices.ptr, GL_STATIC_DRAW);
    }

    void setUVs() {
        glBindBuffer(GL_ARRAY_BUFFER, uvbo);
        glBufferData(GL_ARRAY_BUFFER, data.uvs.length*vec2.sizeof, data.uvs.ptr, GL_STATIC_DRAW);
    }

    void setPoints() {

        // Important check since the user can change this every frame
        enforce(
            points.length == data.points.length, 
            "Data length mismatch, if you want to change the mesh you need to change its data with DynMesh.rebuffer."
        );
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, points.length*vec2.sizeof, points.ptr, GL_DYNAMIC_DRAW);
    }

public:
    /**
        The mesh's transform
    */
    Transform transform;

    /**
        Points in the dynamic mesh
    */
    vec2[] points;

    /**
        Constructs a dynamic mesh
    */
    this(Texture texture, MeshData data, Shader shader = null) {
        this.shader = shader is null ? dynMeshShader : shader;
        this.texture = texture;
        this.data = data;
        this.transform = new Transform();

        // Set the deformable points to their initial position
        this.points = data.points.dup;

        // Generate the buffers
        glGenBuffers(1, &vbo);
        glGenBuffers(1, &uvbo);
        glGenBuffers(1, &ibo);

        mvp = this.shader.getUniformLocation("mvp");

        // Update the indices and UVs
        this.setIndices();
        this.setUVs();
        this.setPoints();
    }

    /**
        Changes this mesh's data
    */
    final void rebuffer(MeshData data) {
        this.data = data;
        this.resetDeform();
        this.setIndices();
        this.setUVs();
    }

    /**
        Returns a copy of the origin points
    */
    final vec2[] originPoints() {
        return data.points.dup;
    }

    /**
        Resets any deformation that has been done to the mesh
    */
    final void resetDeform() {
        this.points = data.points.dup;
    }

    /**
        Mark this mesh as modified
    */
    final void mark() {
        this.marked = true;
    }

    /**
        Draw the mesh using the camera matrix
    */
    void draw(mat4 vp) {

        // Update the points in the mesh if it's marked for an update.
        if (marked) {
            this.setPoints();
            marked = false;
        }

        // Bind our vertex array
        glBindVertexArray(vao);

        // Apply camera
        shader.setUniform(mvp, vp * transform.matrix());
        
        // Use the shader
        shader.use();

        // Bind the texture
        texture.bind();

        // Enable points array
        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Enable UVs array
        glEnableVertexAttribArray(1); // uvs
        glBindBuffer(GL_ARRAY_BUFFER, uvbo);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Bind element array and draw our mesh
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
        glDrawElements(GL_TRIANGLES, cast(int)data.indices.length, GL_UNSIGNED_SHORT, null);

        // Disable the vertex attribs after use
        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
    }

    /**
        Draw debug lines
    */
    void drawDebug(mat4 vp, int lineWidth = 2) {

        // Set debug line width
        glLineWidth(lineWidth);

        // Bind our vertex array
        glBindVertexArray(vao);

        // Apply camera
        shader.setUniform(mvp, vp * transform.matrix());
        
        // Use the shader
        dynMeshDbg.use();

        // Bind the texture
        texture.bind();

        // Enable points array
        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Enable UVs array
        glEnableVertexAttribArray(1); // uvs
        glBindBuffer(GL_ARRAY_BUFFER, uvbo);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

        // Bind element array and draw our mesh
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
        glDrawElements(GL_LINE_STRIP, cast(int)data.indices.length, GL_UNSIGNED_SHORT, null);

        // Disable the vertex attribs after use
        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
    }
}