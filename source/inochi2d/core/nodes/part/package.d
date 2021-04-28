/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.part;
import inochi2d.math;
import inochi2d.core;
import bindbc.opengl;
import std.exception;
import std.algorithm.mutation : copy;

public import inochi2d.core.nodes.part.meshdata;

private {
    GLuint partVAO;
    Shader partShader;
    Shader partMaskShader;
}

package(inochi2d) {
    void inInitPart() {
        glGenVertexArrays(1, &partVAO);
        partShader = new Shader(import("basic/basic.vert"), import("basic/basic.frag"));
        partMaskShader = new Shader(import("basic/basic.vert"), import("basic/basic-mask.frag"));
    }
}

/**
    Masking mode
*/
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
    Dynamic Mesh Part
*/
class Part : Node {
private:
    MeshData data;

    
    GLuint ibo;
    GLuint vbo;
    GLuint uvbo;
    GLint mvp;
    GLint gopacity;

    GLint mmvp;
    GLint mthreshold;
    GLint mgopacity;

    void updateIndices() {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, data.indices.length*ushort.sizeof, data.indices.ptr, GL_STATIC_DRAW);
    }

    void updateUVs() {
        glBindBuffer(GL_ARRAY_BUFFER, uvbo);
        glBufferData(GL_ARRAY_BUFFER, data.uvs.length*vec2.sizeof, data.uvs.ptr, GL_STATIC_DRAW);
    }

    void updateVertices() {

        // Important check since the user can change this every frame
        enforce(
            vertices.length == data.vertices.length, 
            "Data length mismatch, if you want to change the mesh you need to change its data with Part.rebuffer."
        );
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, vertices.length*vec2.sizeof, vertices.ptr, GL_DYNAMIC_DRAW);
    }




    /*
        RENDERING
    */

    void drawSelf(bool isMask = false)() {
        
        // glDisable(GL_CULL_FACE);

        // Bind our vertex array
        glBindVertexArray(partVAO);

        // // Apply camera
        
        // // Use the shader

        static if (isMask) {
            partMaskShader.use();
            partMaskShader.setUniform(mmvp, inGetCamera().matrix * transform.matrix());
            partMaskShader.setUniform(mthreshold, maskAlphaThreshold);
            partMaskShader.setUniform(mgopacity, opacity);
        } else {
            partShader.use();
            partShader.setUniform(mvp, inGetCamera().matrix * transform.matrix());
            partShader.setUniform(gopacity, opacity);
        }

        // Bind the texture
        data.textures[0].bind();

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
        
        glStencilMask(0xFF);
        glStencilFunc(GL_ALWAYS, 1, 0xFF);   
        glDisable(GL_STENCIL_TEST);
    }

    void beginMaskContent() {
        glStencilFunc(GL_EQUAL, 1, 0xFF);
        glStencilMask(0x00);
    }

    void renderMask() {
        
        // Enable writing to stencil buffer and disable writing to color buffer
        glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
        glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
        glStencilFunc(GL_ALWAYS, 1, 0xFF);
        glStencilMask(0xFF);

        // Draw ourselves to the stencil buffer
        drawSelf!true();

        // Disable writing to stencil buffer and enable writing to color buffer
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    }

    // reset mask
    void resetMask() {

        // Check if we want to go a level up
        if (maskingMode == MaskingMode.NoMask) {

            // If we have a parent try to reset to their mask.
            //if (parent !is null) parent.resetMask(vp);
        }

        // We have a mask, reset the stencil buffer to use it.
        beginMask();
        renderMask();
        beginMaskContent();
    }


public:

    /**
        The mesh's vertices
    */
    vec2[] vertices;

    /**
        Masking mode
    */
    MaskingMode maskingMode;
    
    /**
        Alpha Threshold for the masking system, the higher the more opaque pixels will be discarded in the masking process
    */
    float maskAlphaThreshold = 0.01;

    /**
        Opacity of the mesh
    */
    float opacity = 1;

    this(MeshData data, Node parent = null) {
        super(parent);
        this.data = data;

        // Set the deformable points to their initial position
        this.vertices = data.vertices.dup;

        // Generate the buffers
        glGenBuffers(1, &vbo);
        glGenBuffers(1, &uvbo);
        glGenBuffers(1, &ibo);

        mvp = partShader.getUniformLocation("mvp");
        gopacity = partShader.getUniformLocation("opacity");
        
        mmvp = partMaskShader.getUniformLocation("mvp");
        mthreshold = partMaskShader.getUniformLocation("threshold");
        mgopacity = partMaskShader.getUniformLocation("opacity");
        this.updateIndices();
        this.updateUVs();
        this.updateVertices();
    }

    /**
        Changes this mesh's data
    */
    final void rebuffer(MeshData data) {
        this.data = data;
        this.updateIndices();
        this.updateUVs();
        this.updateVertices();
    }

    /**
        Resets the vertices
    */
    void resetVerts() {
        this.vertices = data.vertices.dup;
    }

    override
    void drawOne() {
        glUniform1f(mthreshold, maskAlphaThreshold);
        glUniform1f(mgopacity, opacity);
        drawSelf();
    }

    override
    bool draw() {
        switch(maskingMode) {
            case MaskingMode.ContentMask:

                // Render the mask and self
                drawSelf();
                beginMask();
                renderMask();
                beginMaskContent();

                // Render the children to mask
                foreach(gchild; children) {
                    if (auto child = cast(Part)gchild) {
                        if (child.draw()) {

                            // Reset the masking threshold
                            // Note the threshold changes for every child drawn
                            // We want to make sure it stays up to date
                            glUniform1f(mthreshold, maskAlphaThreshold);
                            glUniform1f(mgopacity, opacity);

                            // Reset mask
                            this.resetMask();
                        }
                    } else {
                        gchild.draw();
                    }
                }

                endMask();
                return true;

            case MaskingMode.StandaloneMask:

                // Render the mask to the stencil buffer only
                beginMask();
                renderMask();
                beginMaskContent();

                // Render the children to mask
                foreach(gchild; children) {
                    if (auto child = cast(Part)gchild) {
                        if (child.draw()) {

                            // Reset the masking threshold
                            // Note the threshold changes for every child drawn
                            // We want to make sure it stays up to date
                            glUniform1f(mthreshold, maskAlphaThreshold);
                            glUniform1f(mgopacity, opacity);

                            // Reset mask
                            this.resetMask();
                        }
                    } else {
                        gchild.draw();
                    }
                }

                endMask();
                return true;
            default: 

                // We're not doing any masking operations here, so just draw ourselves.
                drawSelf();

                // Draw children
                foreach(gchild; children) {
                    if (auto child = cast(Part)gchild) {
                        
                        // Draw children
                        child.draw();

                        // If need be reset to the parent's mask
                        // NOTE: This is to ensure parent masks are retained
                        // NOTE: This is backtracking, it will backtrack until we've reached a mask
                        // Or we've run out of parents to check
                        if (auto parentMesh = cast(Part)parent) {
                            parentMesh.resetMask();
                        }
                    } else {
                        gchild.draw();
                    }
                }
                return false;
        }
    }

}