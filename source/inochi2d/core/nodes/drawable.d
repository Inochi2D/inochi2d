/*
    Inochi2D Drawable base class

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.drawable;
public import inochi2d.core.nodes.defstack;
import inochi2d.integration;
import inochi2d.fmt.serialize;
import inochi2d.math;
import bindbc.opengl;
import std.exception;
import inochi2d.core.dbg;
import inochi2d.core;
import std.string;
import std.typecons: tuple, Tuple;
import std.algorithm.searching;
import std.algorithm.mutation: remove;
import inochi2d.core.nodes.utils;
import std.stdio;

private GLuint drawableVAO;
private const ptrdiff_t NOINDEX = cast(ptrdiff_t)-1;

package(inochi2d) {
    void inInitDrawable() {
        version(InDoesRender) glGenVertexArrays(1, &drawableVAO);
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
protected:

    void updateIndices() {
        version (InDoesRender) {
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, data.indices.length*ushort.sizeof, data.indices.ptr, GL_STATIC_DRAW);
        }
    }

    void updateVertices() {
        version (InDoesRender) {

            // Important check since the user can change this every frame
            glBindBuffer(GL_ARRAY_BUFFER, vbo);
            glBufferData(GL_ARRAY_BUFFER, data.vertices.length*vec2.sizeof, data.vertices.ptr, GL_DYNAMIC_DRAW);
        }

        // Zero-fill the deformation delta
        this.deformation.length = vertices.length;
        foreach(i; 0..deformation.length) {
            this.deformation[i] = vec2(0, 0);
        }
        this.updateDeform();
    }

    Tuple!(vec2[], mat4*, bool) weldingProcessor(Node target, vec2[] origVertices, vec2[] origDeformation, mat4* origTransform) {
        auto linkIndex = welded.countUntil!((a)=>a.target == target)();
        bool changed = false;
        WeldingLink link = welded[linkIndex];
        if (!postProcessed)
            return Tuple!(vec2[], mat4*, bool)(null, null, changed);
        if (weldingApplied[link.target] || link.target.weldingApplied[this])
            return Tuple!(vec2[], mat4*, bool)(null, null, changed);
//        import std.stdio;
//        writefln("welding: %s(%b) --> %s(%b)", name, postProcessed, target.name, target.postProcessed);
        weldingApplied[link.target] = true;
        link.target.weldingApplied[this] = true;
        float weldingWeight = min(1, max(0, link.weight));
        foreach(i, vertex; vertices) {
            if (i >= link.indices.length)
                break;
            auto index = link.indices[i];
            if (index == NOINDEX)
                continue;
            vec2 selfVertex = vertex + deformation[i];
            mat4 selfMatrix = overrideTransformMatrix? overrideTransformMatrix.matrix: transform.matrix;
            selfVertex = (selfMatrix * vec4(selfVertex, 0, 1)).xy;

            vec2 targetVertex = origVertices[index] + origDeformation[index];
            targetVertex = ((*origTransform) * vec4(targetVertex, 0, 1)).xy;

            vec2 newPos = targetVertex * (1 - weldingWeight) + selfVertex * (weldingWeight);

            changed = newPos != selfVertex;

            auto selfMatrixInv = selfMatrix.inverse;
            selfMatrixInv[0][3] = 0;
            selfMatrixInv[1][3] = 0;
            selfMatrixInv[2][3] = 0;
            deformation[i] += (selfMatrixInv * vec4(newPos - selfVertex, 0, 1)).xy;
            version (InDoesRender) {
                glBindBuffer(GL_ARRAY_BUFFER, dbo);
                glBufferData(GL_ARRAY_BUFFER, deformation.length*vec2.sizeof, deformation.ptr, GL_DYNAMIC_DRAW);
            }

            auto targetMatrixInv = (*origTransform).inverse;
            targetMatrixInv[0][3] = 0;
            targetMatrixInv[1][3] = 0;
            targetMatrixInv[2][3] = 0;
            origDeformation[index] += (targetMatrixInv * vec4(newPos - targetVertex, 0, 1)).xy;
        }

        return tuple(origDeformation, cast(mat4*)null, changed);
    }

    void updateDeform() {
        // Important check since the user can change this every frame
        enforce(
            deformation.length == vertices.length, 
            "Data length mismatch for %s, deformation length=%d whereas vertices.length=%d, if you want to change the mesh you need to change its data with Part.rebuffer.".format(name, deformation.length, vertices.length)
        );
        postProcess();

        version (InDoesRender) {
            glBindBuffer(GL_ARRAY_BUFFER, dbo);
            glBufferData(GL_ARRAY_BUFFER, deformation.length*vec2.sizeof, deformation.ptr, GL_DYNAMIC_DRAW);
        }

        this.updateBounds();
    }

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
        version (InDoesRender) {
            // Bind element array and draw our mesh
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
            glDrawElements(GL_TRIANGLES, cast(int)data.indices.length, GL_UNSIGNED_SHORT, null);
        }
    }

    /**
        Allows serializing self data (with pretty serializer)
    */
    override
    void serializeSelfImpl(ref InochiSerializer serializer, bool recursive=true) {
        super.serializeSelfImpl(serializer, recursive);
        serializer.putKey("mesh");
        serializer.serializeValue(data);

        if (welded.length > 0) {
            serializer.putKey("weldedLinks");
            auto state = serializer.arrayBegin();
                foreach(link; welded) {
                    serializer.elemBegin;
                    serializer.serializeValue(link);
                }
            serializer.arrayEnd(state);
        }

    }

    override
    SerdeException deserializeFromFghj(Fghj data) {
        import std.stdio : writeln;
        super.deserializeFromFghj(data);
        if (auto exc = data["mesh"].deserializeValue(this.data)) return exc;

        this.vertices = this.data.vertices.dup;

        if (!data["weldedLinks"].isEmpty) {
            data["weldedLinks"].deserializeValue(this.welded);
        }

        // Update indices and vertices
        this.updateIndices();
        this.updateVertices();
        return null;
    }

    void onDeformPushed(ref Deformation deform) { }

    override
    void preProcess() {
        if (preProcessed)
            return;
        preProcessed = true;
        foreach (preProcessFilter; preProcessFilters) {
            mat4 matrix = (overrideTransformMatrix !is null)? overrideTransformMatrix.matrix: this.transform.matrix;
            auto filterResult = preProcessFilter(this, vertices, deformation, &matrix);
            if (filterResult[0] !is null) {
                deformation = filterResult[0];
            } 
            if (filterResult[1] !is null) {
                overrideTransformMatrix = new MatrixHolder(*filterResult[1]);
            }
        }
    }

    override
    void postProcess() {
        if (postProcessed)
            return;
        postProcessed = true;
        foreach (postProcessFilter; postProcessFilters) {
            mat4 matrix = (overrideTransformMatrix !is null)? overrideTransformMatrix.matrix: this.transform.matrix;
            auto filterResult = postProcessFilter(this, vertices, deformation, &matrix);
            if (filterResult[0] !is null) {
                deformation = filterResult[0];
            } 
            if (filterResult[1] !is null) {
                overrideTransformMatrix = new MatrixHolder(*filterResult[1]);
            }
        }
    }

package(inochi2d):
    final void notifyDeformPushed(ref Deformation deform) {
        onDeformPushed(deform);
    }

public:

    struct WeldingLink {
        @Name("targetUUID")
        uint targetUUID; 
        @Ignore
        Drawable target;
        @Name("indices")
        ptrdiff_t[] indices;
        @Name("weight")
        float weight;
    };
    WeldingLink[] welded;
    bool[Drawable] weldingApplied;

    abstract void renderMask(bool dodge = false);

    /**
        Constructs a new drawable surface
    */
    this(Node parent = null) {
        super(parent);

        version(InDoesRender) {

            // Generate the buffers
            glGenBuffers(1, &vbo);
            glGenBuffers(1, &ibo);
            glGenBuffers(1, &dbo);
        }

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

        version(InDoesRender) {
            
            // Generate the buffers
            glGenBuffers(1, &vbo);
            glGenBuffers(1, &ibo);
            glGenBuffers(1, &dbo);
        }

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
        weldingApplied.clear();
        overrideTransformMatrix = null;
        foreach (link; welded)
            weldingApplied[link.target] = false;
        super.beginUpdate();
    }

    /**
        Updates the drawable
    */
    override
    void update() {
        preProcess();
        deformStack.update();
        super.update();
        this.updateDeform();
    }

    /**
        Draws the drawable
    */
    override
    void drawOne() {
        super.drawOne();
    }

    /**
        Draws the drawable without any processing
    */
    void drawOneDirect(bool forMasking) { }

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
        mat4 matrix = getDynamicMatrix();
        foreach(i, vertex; vertices) {
            vec2 vertOriented = vec2(matrix * vec4(vertex+deformation[i], 0, 1));
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
    
    version (InDoesRender) {
        /**
            Draws line of mesh
        */
        void drawMeshLines() {
            if (vertices.length == 0) return;

            auto trans = getDynamicMatrix();

            ushort[] indices = data.indices;

            vec3[] points = new vec3[indices.length*2];
            foreach(i; 0..indices.length/3) {
                size_t ix = i*3;
                size_t iy = ix*2;
                auto indice = indices[ix];

                points[iy+0] = vec3(vertices[indice]-data.origin+deformation[indice], 0);
                points[iy+1] = vec3(vertices[indices[ix+1]]-data.origin+deformation[indices[ix+1]], 0);

                points[iy+2] = vec3(vertices[indices[ix+1]]-data.origin+deformation[indices[ix+1]], 0);
                points[iy+3] = vec3(vertices[indices[ix+2]]-data.origin+deformation[indices[ix+2]], 0);

                points[iy+4] = vec3(vertices[indices[ix+2]]-data.origin+deformation[indices[ix+2]], 0);
                points[iy+5] = vec3(vertices[indice]-data.origin+deformation[indice], 0);
            }

            inDbgSetBuffer(points);
            inDbgDrawLines(vec4(.5, .5, .5, 1), trans);
        }

        /**
            Draws the points of the mesh
        */
        void drawMeshPoints() {
            if (vertices.length == 0) return;

            auto trans = getDynamicMatrix();
            vec3[] points = new vec3[vertices.length];
            foreach(i, point; vertices) {
                points[i] = vec3(point-data.origin+deformation[i], 0);
            }

            inDbgSetBuffer(points);
            inDbgPointsSize(8);
            inDbgDrawPoints(vec4(0, 0, 0, 1), trans);
            inDbgPointsSize(4);
            inDbgDrawPoints(vec4(1, 1, 1, 1), trans);
        }
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

    void addWeldedTarget(Drawable target, ptrdiff_t[] weldedVertexIndices, float weldingWeight) {
        // FIXME: must check whether target is already added.
        auto index = welded.countUntil!"a.target == b"(target);
        if (index != -1)
            return;
        auto link = WeldingLink(target.uuid, target, weldedVertexIndices, weldingWeight);
        welded ~= link;

        ptrdiff_t[] counterWeldedVertexIndices;
        counterWeldedVertexIndices.length = target.vertices.length;
        counterWeldedVertexIndices[0..$] = -1;
        foreach (i, ind; weldedVertexIndices) {
            if (ind != NOINDEX)
                counterWeldedVertexIndices[ind] = i;
        }
        auto counterLink = WeldingLink(uuid, this, counterWeldedVertexIndices, 1 - weldingWeight);
        target.welded ~= counterLink;

        target.postProcessFilters ~= &weldingProcessor;
        postProcessFilters ~= &target.weldingProcessor;
    }

    void removeWeldedTarget(Drawable target) {
        auto index = welded.countUntil!((a) => a.target == target)();
        if (index != -1) {
            welded = welded.remove(index);
            postProcessFilters = postProcessFilters.removeByValue(&target.weldingProcessor);
        }
        index = target.welded.countUntil!((a) => a.target == this)();
        if (index != -1) {
            target.welded = target.welded.remove(index);
            target.postProcessFilters = target.postProcessFilters.removeByValue(&weldingProcessor);
        }
    }

    bool isWeldedBy(Drawable target) {
        return welded.countUntil!"a.target == b"(target) != -1;
    }

    override
    void setupSelf() {
        foreach (link; welded) {
            if (postProcessFilters.countUntil(&link.target.weldingProcessor) == -1)
                postProcessFilters ~= &link.target.weldingProcessor;
        }
    }

    override
    void finalize() {
        super.finalize();
        
        WeldingLink[] validLinks;
        foreach(i; 0..welded.length) {
            if (Drawable nLink = puppet.find!Drawable(welded[i].targetUUID)) {
                welded[i].target = nLink;
                validLinks ~= welded[i];
            }
        }

        // Remove invalid welded links
        welded = validLinks;
        setupSelf();
    }

    override
    void normalizeUV(MeshData* data) {
        import std.algorithm: map;
        import std.algorithm: minElement, maxElement;
        if (data.uvs.length != 0) {
            float minX = data.uvs.map!(a => a.x).minElement;
            float maxX = data.uvs.map!(a => a.x).maxElement;
            float minY = data.uvs.map!(a => a.y).minElement;
            float maxY = data.uvs.map!(a => a.y).maxElement;
            float width = maxX - minX;
            float height = maxY - minY;
            float centerX = (minX + maxX) / 2 / width;
            float centerY = (minY + maxY) / 2 / height;
            foreach(i; 0..data.uvs.length) {
                data.uvs[i].x /= width;
                data.uvs[i].y /= height;
                data.uvs[i] += vec2(0.5 - centerX, 0.5 - centerY);
            }
        }
    }

    override
    void centralize() {
        foreach (child; children) {
            child.centralize();
        }
        updateBounds();
    }

    override
    void copyFrom(Node src, bool inPlace = false, bool deepCopy = true) {
        super.copyFrom(src, inPlace, deepCopy);
        if (auto drawable = cast(Drawable)src) {
            MeshData newData;
            newData.vertices = drawable.data.vertices.dup;
            newData.uvs = drawable.data.uvs.dup;
            newData.indices = drawable.data.indices.dup;
            if (drawable.data.gridAxes.length > 0) {
                foreach (ax; drawable.data.gridAxes) {
                    newData.gridAxes ~= ax.dup;
                }
            }
            rebuffer(newData);
            deformation = drawable.deformation.dup;
        }
    }

    override
    void build(bool force = false) { 
        foreach (child; children) {
            setupChild(child);
        }
        setupSelf();
        super.build(force);
    }

}

version (InDoesRender) {
    /**
        Begins a mask

        This causes the next draw calls until inBeginMaskContent/inBeginDodgeContent or inEndMask 
        to be written to the current mask.

        This also clears whatever old mask there was.
    */
    void inBeginMask(bool hasMasks) {

        // Enable and clear the stencil buffer so we can write our mask to it
        glEnable(GL_STENCIL_TEST);
        glClearStencil(hasMasks ? 0 : 1);
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
        Starts masking content

        NOTE: This have to be run within a inBeginMask and inEndMask block!
    */
    void inBeginMaskContent() {

        glStencilFunc(GL_EQUAL, 1, 0xFF);
        glStencilMask(0x00);
    }
}