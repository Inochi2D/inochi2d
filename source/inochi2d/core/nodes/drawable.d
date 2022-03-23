/*
    Inochi2D Drawable base class

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.drawable;
public import inochi2d.core.nodes.defstack;
import inochi2d.fmt.serialize;
import inochi2d.math;
import inochi2d.core.nodes;
import bindbc.opengl;
import std.exception;
import inochi2d.core.dbg;

private GLuint drawableVAO;

package(inochi2d) {
    void inInitDrawable() {
        glGenVertexArrays(1, &drawableVAO);
    }


    /**
        Binds the internal vertex array for rendering
    */
    void incDrawableBindVAO() {

        // Bind our vertex array
        glBindVertexArray(drawableVAO);
    }

    bool doGenerateBounds = false;
}

/**
    Sets whether Inochi2D should keep track of the bounds
*/
void inSetUpdateBounds(bool state) {
    doGenerateBounds = state;
}

/**
    Nodes that are meant to render something in to the Inochi2D scene
    Other nodes don't have to render anything and serve mostly other 
    purposes.

    The main types of Drawables are Parts and Masks
*/

@TypeId("Drawable")
abstract class Drawable : Node {
private:
    void updateIndices() {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, data.indices.length*ushort.sizeof, data.indices.ptr, GL_STATIC_DRAW);
    }

    void updateVertices() {

        // Important check since the user can change this every frame
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, data.vertices.length*vec2.sizeof, data.vertices.ptr, GL_DYNAMIC_DRAW);

        // Zero-fill the deformation delta
        this.deformation.length = vertices.length;
        foreach(i; 0..deformation.length) {
            this.deformation[i] = vec2(0, 0);
        }
        this.updateDeform();
    }

    void updateDeform() {
    
        // Important check since the user can change this every frame
        enforce(
            deformation.length == vertices.length, 
            "Data length mismatch, if you want to change the mesh you need to change its data with Part.rebuffer."
        );

        glBindBuffer(GL_ARRAY_BUFFER, dbo);
        glBufferData(GL_ARRAY_BUFFER, this.deformation.length*vec2.sizeof, this.deformation.ptr, GL_DYNAMIC_DRAW);

        this.updateBounds();
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
        OpenGL Vertex Buffer Object for deformation
    */
    GLuint dbo;

    /**
        The mesh data of this part

        NOTE: DO NOT MODIFY!
        The data in here is only to be used for reference.
    */
    MeshData data;

    /**
        Binds Index Buffer for rendering
    */
    final void bindIndex() {

        // Bind element array and draw our mesh
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
        glDrawElements(GL_TRIANGLES, cast(int)data.indices.length, GL_UNSIGNED_SHORT, null);
    }

    abstract void renderMask();

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void serializeSelf(ref InochiSerializer serializer) {
        super.serializeSelf(serializer);
        serializer.putKey("mesh");
        serializer.serializeValue(data);
    }

    /**
        Allows serializing self data (with compact serializer)
    */
    override
    void serializeSelf(ref InochiSerializerCompact serializer) {
        super.serializeSelf(serializer);
        serializer.putKey("mesh");
        serializer.serializeValue(data);
    }

    override
    SerdeException deserializeFromAsdf(Asdf data) {
        import std.stdio : writeln;
        super.deserializeFromAsdf(data);
        if (auto exc = data["mesh"].deserializeValue(this.data)) return exc;

        this.vertices = this.data.vertices.dup;

        // Update indices and vertices
        this.updateIndices();
        this.updateVertices();
        return null;
    }

public:

    /**
        Constructs a new drawable surface
    */
    this(Node parent = null) {
        super(parent);

        // Generate the buffers
        glGenBuffers(1, &vbo);
        glGenBuffers(1, &ibo);
        glGenBuffers(1, &dbo);

        // Create deformation stack
        this.deformStack = DeformationStack(this);
    }

    /**
        Constructs a new drawable surface
    */
    this(MeshData data, Node parent = null) {
        this(data, inCreateUUID(), parent);
    }

    /**
        Constructs a new drawable surface
    */
    this(MeshData data, uint uuid, Node parent = null) {
        super(uuid, parent);
        this.data = data;
        this.deformStack = DeformationStack(this);

        // Set the deformable points to their initial position
        this.vertices = data.vertices.dup;

        // Generate the buffers
        glGenBuffers(1, &vbo);
        glGenBuffers(1, &ibo);
        glGenBuffers(1, &dbo);

        // Update indices and vertices
        this.updateIndices();
        this.updateVertices();
    }

    ref vec2[] vertices() {
        return data.vertices;
    }

    /**
        Deformation offset to apply
    */
    vec2[] deformation;

    /**
        The bounds of this drawable
    */
    vec4 bounds;

    /**
        Deformation stack
    */
    DeformationStack deformStack;

    /**
        Refreshes the drawable, updating its vertices
    */
    final void refresh() {
        this.updateVertices();
    }
    
    /**
        Refreshes the drawable, updating its deformation deltas
    */
    final void refreshDeform() {
        this.updateDeform();
    }

    override
    void beginUpdate() {
        deformStack.preUpdate();
        super.beginUpdate();
    }

    /**
        Updates the drawable
    */
    override
    void update() {
        super.update();
        deformStack.update();
        this.updateDeform();
    }

    /**
        Updates the drawable
    */
    override
    void drawOne() {
        super.drawOne();
    }

    override
    string typeId() { return "Drawable"; }

    /**
        Updates the drawable's bounds
    */
    void updateBounds() {
        if (!doGenerateBounds) return;

        // Calculate bounds
        Transform wtransform = transform;
        bounds = vec4(wtransform.translation.xyxy);
        foreach(i, vertex; vertices) {
            vec2 vertOriented = vec2(transform.matrix * vec4(vertex+deformation[i], 0, 1));
            if (vertOriented.x < bounds.x) bounds.x = vertOriented.x;
            if (vertOriented.y < bounds.y) bounds.y = vertOriented.y;
            if (vertOriented.x > bounds.z) bounds.z = vertOriented.x;
            if (vertOriented.y > bounds.w) bounds.w = vertOriented.y;
        }
    }

    /**
        Draws bounds
    */
    override
    void drawBounds() {
        if (!doGenerateBounds) return;
        if (vertices.length == 0) return;
        
        float width = bounds.z-bounds.x;
        float height = bounds.w-bounds.y;
        inDbgSetBuffer([
            vec3(bounds.x, bounds.y, 0),
            vec3(bounds.x + width, bounds.y, 0),
            
            vec3(bounds.x + width, bounds.y, 0),
            vec3(bounds.x + width, bounds.y+height, 0),
            
            vec3(bounds.x + width, bounds.y+height, 0),
            vec3(bounds.x, bounds.y+height, 0),
            
            vec3(bounds.x, bounds.y+height, 0),
            vec3(bounds.x, bounds.y, 0),
        ]);
        inDbgLineWidth(3);
        inDbgDrawLines(vec4(.5, .5, .5, 1));
        inDbgLineWidth(1);
    }
    
    /**
        Draws line of mesh
    */
    void drawMeshLines() {
        if (vertices.length == 0) return;

        auto trans = transform.matrix();
        ushort[] indices = data.indices;

        vec3[] points = new vec3[indices.length*2];
        foreach(i; 0..indices.length/3) {
            size_t ix = i*3;
            size_t iy = ix*2;
            auto indice = indices[ix];

            points[iy+0] = vec3(vertices[indice], 0);
            points[iy+1] = vec3(vertices[indices[ix+1]], 0);

            points[iy+2] = vec3(vertices[indices[ix+1]], 0);
            points[iy+3] = vec3(vertices[indices[ix+2]], 0);

            points[iy+4] = vec3(vertices[indices[ix+2]], 0);
            points[iy+5] = vec3(vertices[indice], 0);
        }

        inDbgSetBuffer(points);
        inDbgDrawLines(vec4(.5, .5, .5, 1), trans);
    }

    /**
        Draws the points of the mesh
    */
    void drawMeshPoints() {
        if (vertices.length == 0) return;

        auto trans = transform.matrix();
        vec3[] points = new vec3[vertices.length];
        foreach(i, point; vertices) {
            points[i] = vec3(point, 0);
        }

        inDbgSetBuffer(points);
        inDbgPointsSize(8);
        inDbgDrawPoints(vec4(0, 0, 0, 1), trans);
        inDbgPointsSize(4);
        inDbgDrawPoints(vec4(1, 1, 1, 1), trans);
    }

    /**
        Returns the mesh data for this Part.
    */
    final ref MeshData getMesh() {
        return this.data;
    }

    /**
        Changes this mesh's data
    */
    void rebuffer(ref MeshData data) {
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

/**
    Begins a mask

    This causes the next draw calls until inBeginMaskContent/inBeginDodgeContent or inEndMask 
    to be written to the current mask.

    This also clears whatever old mask there was.
*/
void inBeginMask() {

    // Enable and clear the stencil buffer so we can write our mask to it
    glEnable(GL_STENCIL_TEST);
    glClear(GL_STENCIL_BUFFER_BIT);
}

/**
    End masking

    Once masking is ended content will no longer be masked by the defined mask.
*/
void inEndMask() {

    // We're done stencil testing, disable it again so that we don't accidentally mask more stuff out
    glStencilMask(0xFF);
    glStencilFunc(GL_ALWAYS, 1, 0xFF);   
    glDisable(GL_STENCIL_TEST);
}

/**
    Stars masking content

    NOTE: This have to be run within a inBeginMask and inEndMask block!
*/
void inBeginMaskContent() {
    glStencilFunc(GL_EQUAL, 1, 0xFF);
    glStencilMask(0x00);
}

/**
    Stars dodging content

    NOTE: This have to be run within a inBeginMask and inEndMask block!
*/
void inBeginDodgeContent() {

    // This tells OpenGL that as long as the stencil buffer is 0
    // in other words that the dodge texture was not drawn there
    // that it's okay to draw there.
    //
    // This effectively makes so that the dodge reference cuts out
    // a part of this part's texture where they overlap.
    glStencilFunc(GL_NOTEQUAL, 1, 0xFF);
    glStencilMask(0x00);
}