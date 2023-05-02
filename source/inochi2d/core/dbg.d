module inochi2d.core.dbg;
import inochi2d;
import bindbc.opengl;

package(inochi2d) {
    int indiceCount;

    Shader dbgShaderLine;
    Shader dbgShaderPoint;
    GLuint dbgVAO;
    GLuint dbgVBO;
    GLuint dbgIBO;

    GLuint cVBO;

    GLint mvpId;
    GLint colorId;
    void inInitDebug() {
        dbgShaderLine = new Shader(import("dbg.vert"), import("dbgline.frag"));
        dbgShaderPoint = new Shader(import("dbg.vert"), import("dbgpoint.frag"));
        glGenVertexArrays(1, &dbgVAO);
        glGenBuffers(1, &dbgVBO);
        glGenBuffers(1, &dbgIBO);

        mvpId = dbgShaderLine.getUniformLocation("mvp");
        colorId = dbgShaderLine.getUniformLocation("color");
    }
}

private {
    void inUpdateDbgVerts(vec3[] points) {

        // Generate bad line drawing indices
        ushort[] vts = new ushort[points.length+1];
        foreach(i; 0..points.length) {
            vts[i] = cast(ushort)i;
        }
        vts[$-1] = 0;

        inUpdateDbgVerts(points, vts);
    }

    void inUpdateDbgVerts(vec3[] points, ushort[] indices) {
        glBindVertexArray(dbgVAO);
        glBindBuffer(GL_ARRAY_BUFFER, dbgVBO);
        glBufferData(GL_ARRAY_BUFFER, points.length*vec3.sizeof, points.ptr, GL_DYNAMIC_DRAW);
        cVBO = dbgVBO;

    
        indiceCount = cast(int)indices.length;
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, dbgIBO);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.length*ushort.sizeof, indices.ptr, GL_DYNAMIC_DRAW);
    }
}

bool inDbgDrawMeshOutlines = false;
bool inDbgDrawMeshVertexPoints = false;
bool inDbgDrawMeshOrientation = false;

/**
    Size of debug points
*/
void inDbgPointsSize(float size) {
    glPointSize(size);
}

/**
    Size of debug points
*/
void inDbgLineWidth(float size) {
    glLineWidth(size);
}

/**
    Draws points with specified color
*/
void inDbgSetBuffer(vec3[] points) {
    inUpdateDbgVerts(points);
}

/**
    Sets buffer to buffer owned by an other OpenGL object
*/
void inDbgSetBuffer(GLuint vbo, GLuint ibo, int count) {
    glBindVertexArray(dbgVAO);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    cVBO = vbo;
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
    indiceCount = count;
}

/**
    Draws points with specified color
*/
void inDbgSetBuffer(vec3[] points, ushort[] indices) {
    inUpdateDbgVerts(points, indices);
}

/**
    Draws current stored vertices as points with specified color
*/
void inDbgDrawPoints(vec4 color, mat4 transform = mat4.identity) {
    glBlendEquation(GL_FUNC_ADD);
    glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);

        glBindVertexArray(dbgVAO);

        dbgShaderPoint.use();
        dbgShaderPoint.setUniform(mvpId, inGetCamera().matrix * transform);
        dbgShaderPoint.setUniform(colorId, color);

        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, cVBO);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);
        
        glDrawElements(GL_POINTS, indiceCount, GL_UNSIGNED_SHORT, null);
        glDisableVertexAttribArray(0);

    glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);
}

/**
    Draws current stored vertices as lines with specified color
*/
void inDbgDrawLines(vec4 color, mat4 transform = mat4.identity) {
    glEnable(GL_LINE_SMOOTH);
    glBlendEquation(GL_FUNC_ADD);
    glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);
    
        glBindVertexArray(dbgVAO);

        dbgShaderLine.use();
        dbgShaderLine.setUniform(mvpId, inGetCamera().matrix * transform);
        dbgShaderLine.setUniform(colorId, color);

        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, cVBO);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);
        
        glDrawElements(GL_LINES, indiceCount, GL_UNSIGNED_SHORT, null);
        glDisableVertexAttribArray(0);

    glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);
    glDisable(GL_LINE_SMOOTH);
}