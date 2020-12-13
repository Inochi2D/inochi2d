/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.render.mesh.dynmesh;
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

enum MaskingMode {
    /**
        The mesh should not act as a mask
    */
    NoMask,

    /**
        The mesh draws itself and then masks children
    */
    ContentMask,

    /**
        The mesh is a standalone mask, its texture should not be drawn
    */
    StandaloneMask
}

/**
    A dynamic deformable textured mesh
*/
class DynMesh {
private:
    Shader shader;
    MeshData data;
    int activeTexture;
    GLuint ibo;
    GLuint vbo;
    GLuint uvbo;

    // View-projection matrix uniform location
    GLint mvp;
    GLint threshold;

    // Whether this mesh is marked for an update
    bool marked;

    void setIndices() {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, data.indices.length*ushort.sizeof, data.indices.ptr, GL_STATIC_DRAW);
    }

    void genUVs() {
        // Generate the appropriate UVs
        vec2[] uvs = data.genUVsFor(activeTexture);

        glBindBuffer(GL_ARRAY_BUFFER, uvbo);
        glBufferData(GL_ARRAY_BUFFER, uvs.length*vec2.sizeof, uvs.ptr, GL_STATIC_DRAW);
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

    void drawSelf(mat4 vp) {

        // Bind our vertex array
        glBindVertexArray(vao);

        // Apply camera
        shader.setUniform(mvp, vp * transform.matrix());
        
        // Use the shader
        shader.use();

        // Bind the texture
        data.textures[activeTexture].texture.bind();

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

    void beginMask() {

        // Enable and clear the stencil buffer so we can write our mask to it
        glEnable(GL_STENCIL_TEST);
        glClear(GL_STENCIL_BUFFER_BIT);
    }

    void endMask() {

        // We're done stencil testing, disable it again so that we don't accidentally mask more stuff out
        glDisable(GL_STENCIL_TEST);
    }

    void beginMaskContent() {
        glStencilFunc(GL_EQUAL, 1, 0xFF);
    }

    void renderMask(bool colorAllowed)(mat4 vp) {
        // Enable writing to stencil buffer and disable writing to color buffer
        static if (!colorAllowed) glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
        glStencilOp(GL_KEEP, GL_REPLACE, GL_REPLACE);
        glStencilFunc(GL_ALWAYS, 1, 0xFF);
        glStencilMask(0xFF);

        // Draw ourselves to the stencil buffer
        drawSelf(vp);

        // Disable writing to stencil buffer and enable writing to color buffer
        glStencilMask(0x00);
        static if (!colorAllowed) glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
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
        Whether the mesh masks sub-meshes
    */
    MaskingMode maskingMode;
    
    /**
        Alpha Threshold for the masking system, the higher the more opaque pixels will be discarded in the masking process
    */
    float maskAlphaThreshold = 0.01;

    /**
        Children meshes
    */
    DynMesh[] children;    

    /**
        Constructs a dynamic mesh
    */
    this(MeshData data, Shader shader = null) {
        this.shader = shader is null ? dynMeshShader : shader;
        this.data = data;
        this.transform = new Transform();

        // Set the deformable points to their initial position
        this.points = data.points.dup;

        // Generate the buffers
        glGenBuffers(1, &vbo);
        glGenBuffers(1, &uvbo);
        glGenBuffers(1, &ibo);

        mvp = this.shader.getUniformLocation("mvp");
        threshold = this.shader.getUniformLocation("threshold");

        // Update the indices and UVs
        this.setIndices();
        this.genUVs();
        this.setPoints();
    }

    /**
        Changes this mesh's data
    */
    final void rebuffer(MeshData data) {
        this.data = data;
        this.resetDeform();
        this.setIndices();
        this.genUVs();
    }

    /**
        Gets all points in a radius around the specified point
    */
    size_t[] pointsAround(size_t i, float radius = 128f) {
        size_t[] p;
        vec2 pointPos = points[i];
        foreach(j, point; points) {
            
            // We don't want to add the point itself
            if (j == i) continue;

            // Add any points inside the search area to the list
            if (point.distance(pointPos) < radius) p ~= j;
        }
        return p;
    }

    /**
        Gets all points in a radius around the specified vector
    */
    size_t[] pointsAround(vec2 pos, float radius = 128f) {
        size_t[] p;
        foreach(j, point; points) {

            // Add any points inside the search area to the list
            if (point.distance(pos) < radius) p ~= j;
        }
        return p;
    }

    /**
        Pulls a vertex and surrounding verticies in a specified direction
    */
    void pull(size_t ix, vec2 direction, float smoothArea = 128f) {
        vec2 pointPos = points[ix];
				
        points[ix] -= vec2(direction.x, direction.y);

        foreach(i, point; points) {
            
            // We don't want to double pull on our vertex
            if (i == ix) continue;

            // We want to subtly pull other surrounding points
            if (point.distance(pointPos) < smoothArea) {

                // Pulling power decreases linearly the further out we go
                immutable(float) pullPower = (smoothArea-point.distance(pointPos))/smoothArea;

                points[i] -= vec2(direction.x*pullPower, direction.y*pullPower);
            }
        }
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

        Returns:
            true if a masking operation was done
            false if there was no masking done
    */
    bool draw(mat4 vp) {

        // Update the points in the mesh if it's marked for an update.
        if (marked) {
            this.setPoints();
            marked = false;
        }

        // Set the masking threshold
        glUniform1f(threshold, maskAlphaThreshold);

        switch(maskingMode) {
            case MaskingMode.ContentMask:

                beginMask();

                renderMask!true(vp);

                beginMaskContent();

                foreach(child; children) {
                    if (child.draw(vp)) {

                        // Reset the masking threshold
                        // Note the threshold changes for every child drawn
                        // We want to make sure it stays up to date
                        glUniform1f(threshold, maskAlphaThreshold);

                        // We need to redo our mask because a child replaced it
                        beginMask();
                        renderMask!true(vp);

                        // We can then begin rendering content again
                        beginMaskContent();
                    }
                }

                endMask();
                return true;

            case MaskingMode.StandaloneMask:

                beginMask();

                renderMask!false(vp);

                beginMaskContent();

                foreach(child; children) {
                    if (child.draw(vp)) {

                        // Reset the masking threshold
                        // Note the threshold changes for every child drawn
                        // We want to make sure it stays up to date
                        glUniform1f(threshold, maskAlphaThreshold);

                        // We need to redo our mask because a child replaced it
                        beginMask();
                        renderMask!false(vp);

                        // We can then begin rendering content again
                        beginMaskContent();
                    }
                }

                endMask();
                return true;
            default: return false;
        }
    }
}