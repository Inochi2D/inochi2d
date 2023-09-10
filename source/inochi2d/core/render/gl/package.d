module inochi2d.core.render.gl;
import inochi2d.core.render;
import inochi2d.core.render.ftable;
import bindbc.opengl;

/**
    Sets the current renderer to one of the built-in OpenGL renderers

    Current supported versions:
    * 3.1
*/
bool inRenderSetGL(string ver) {
    InRendererFuncTable* table = new InRendererFuncTable;
    switch(ver) {
        case "3.1":
            table.isThreadsafe = &incRenderGLIsThreadsafe;
            table.construct = &incRenderGLConstruct;
            table.destruct = &incRenderGLDestruct;
            table.allocateTexture = &incRenderGLAllocateTexture;
            table.deallocateTexture = &incRenderGLDeallocateTexture;
            return inRenderSet(table);
        default: return false;
    }
}

private:

__gshared GLSupport loaded = GLSupport.noLibrary;

extern(C) nothrow:
bool incRenderGLIsThreadsafe() {
    return false;
}

bool incRenderGLConstruct() {
    GLSupport support = loadOpenGL();
    switch(support) {
        case GLSupport.badLibrary:
        case GLSupport.noLibrary:
        case GLSupport.noContext:
            return false;
        
        default:
            loaded = support;
            return true;
    }

    // TODO: Handle various GL versions and return an error if too low version
    // is returned.

    // TODO: Check for advanced blending support
}

bool incRenderGLDestruct() {
    if (loaded != GLSupport.noLibrary) {
        unloadOpenGL();
        loaded = GLSupport.noLibrary;
        return true;
    }
    return false;
}

/**
    Allocates texture
*/
void* incRenderGLAllocateTexture(ubyte* data, uint width, uint height, uint channels) {
    GLuint id;
    glGenTextures(1, &id);

    GLint fmt;
    switch(channels) {
        case 1:
            fmt = GL_RED;
            break;
        case 2:
            fmt = GL_RG;
            break;
        case 3:
            fmt = GL_RGB;
            break;
        case 4:
            fmt = GL_RGBA;
            break;

        default: return null;
    }

    glBindTexture(GL_TEXTURE_2D, id);
    glTexImage2D(GL_TEXTURE_2D, 0, fmt, width, height, 0, fmt, GL_UNSIGNED_BYTE, data);

    return cast(void*)id;
}

/**
    Deallocates texture
*/
void incRenderGLDeallocateTexture(void* texture) {
    if (texture !is null) {
        GLuint texId = cast(GLuint)texture;
        glDeleteTextures(1, &texId);
    }
}

void incRenderGLFinalizeNode(InRID rid, ref InRenderData data) {
    
}

void incRenderGLCleanupNode(InRID rid, ref InRenderData data) {

}

