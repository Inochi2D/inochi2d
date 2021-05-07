module inochi2d.core.nodes.drawable;
import inochi2d.math;
import inochi2d.core.nodes;
import bindbc.opengl;
import std.exception;

private GLuint drawableVAO;

package(inochi2d) {
    void inInitDrawable() {
        glGenVertexArrays(1, &drawableVAO);
    }
}

/**
    A drawable
*/
abstract class Drawable : Node {
private:
    void updateIndices() {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, data.indices.length*ushort.sizeof, data.indices.ptr, GL_STATIC_DRAW);
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

protected:
    /**
        OpenGL Index Buffer Object
    */
    GLuint ibo;

    /**
        OpenGL Vertex Buffer Object
    */
    GLuint vbo;

    /**
        The mesh data of this part

        NOTE: DO NOT MODIFY!
        The data in here is only to be used for reference.
    */
    MeshData data;

    /**
        Binds the internal vertex array for rendering
    */
    final void bindVertexArray() {

        // Bind our vertex array
        glBindVertexArray(drawableVAO);
    }

    /**
        Binds Index Buffer for rendering
    */
    final void bindIndex() {
        // Bind element array and draw our mesh
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
        glDrawElements(GL_TRIANGLES, cast(int)data.indices.length, GL_UNSIGNED_SHORT, null);
    }

    abstract void renderMask();

public:

    /**
        Constructs a new drawable surface
    */
    this(MeshData data, Node parent = null) {
        super(parent);
        this.data = data;

        // Set the deformable points to their initial position
        this.vertices = data.vertices.dup;

        // Generate the buffers
        glGenBuffers(1, &vbo);
        glGenBuffers(1, &ibo);

        // Update indices and vertices
        this.updateIndices();
        this.updateVertices();
    }

    /**
        The mesh's vertices
    */
    vec2[] vertices;

    /**
        Updates the drawable
    */
    override
    void update() {
        this.updateVertices();
    }

    /**
        Returns the mesh data for this Part.
    */
    final MeshData getMesh() {
        return this.data;
    }

    /**
        Changes this mesh's data
    */
    void rebuffer(MeshData data) {
        this.data = data;
        this.updateIndices();
        this.updateVertices();
    }
    
    /**
        Resets the vertices of this drawable
    */
    final void reset() {
        vertices[] = data.vertices;
    }

}