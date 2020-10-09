/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.render.shader;
import inochi2d.math;
import std.string;
import bindbc.opengl;

/**
    A shader
*/
class Shader {
private:
    GLuint shaderProgram;
    GLuint fragShader;
    GLuint vertShader;

    void compileShaders(string vertex, string fragment) {

        // Compile vertex shader
        vertShader = glCreateShader(GL_VERTEX_SHADER);
        auto c_vert = vertex.toStringz;
        glShaderSource(vertShader, 1, &c_vert, null);
        glCompileShader(vertShader);
        verifyShader(vertShader);

        // Compile fragment shader
        fragShader = glCreateShader(GL_FRAGMENT_SHADER);
        auto c_frag = fragment.toStringz;
        glShaderSource(fragShader, 1, &c_frag, null);
        glCompileShader(fragShader);
        verifyShader(fragShader);

        // Attach and link them
        shaderProgram = glCreateProgram();
        glAttachShader(shaderProgram, vertShader);
        glAttachShader(shaderProgram, fragShader);
        glLinkProgram(shaderProgram);
        verifyProgram();
    }

    void verifyShader(GLuint shader) {

        // Get the length of the error log
        GLint logLength;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {

            // Fetch the error log
            char[] log = new char[logLength];
            glGetShaderInfoLog(shader, logLength, null, log.ptr);

            throw new Exception(cast(string)log);
        }
    }

    void verifyProgram() {

        // Get the length of the error log
        GLint logLength;
        glGetProgramiv(shaderProgram, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {

            // Fetch the error log
            char[] log = new char[logLength];
            glGetProgramInfoLog(shaderProgram, logLength, null, log.ptr);

            throw new Exception(cast(string)log);
        }
    }

public:

    /**
        Destructor
    */
    ~this() {
        glDetachShader(shaderProgram, vertShader);
        glDetachShader(shaderProgram, fragShader);
        glDeleteProgram(shaderProgram);
        
        glDeleteShader(fragShader);
        glDeleteShader(vertShader);
    }

    /**
        Creates a new shader object from source
    */
    this(string vertex, string fragment) {
        compileShaders(vertex, fragment);
    }

    /**
        Use the shader
    */
    void use() {
        glUseProgram(shaderProgram);
    }

    GLint getUniformLocation(string name) {
        return glGetUniformLocation(shaderProgram, name.ptr);
    }

    void setUniform(GLint uniform, bool value) {
        glUniform1i(uniform, cast(int)value);
    }

    void setUniform(GLint uniform, int value) {
        glUniform1i(uniform, value);
    }

    void setUniform(GLint uniform, float value) {
        glUniform1f(uniform, value);
    }

    void setUniform(GLint uniform, vec2 value) {
        glUniform2f(uniform, value.x, value.y);
    }

    void setUniform(GLint uniform, vec3 value) {
        glUniform3f(uniform, value.x, value.y, value.z);
    }

    void setUniform(GLint uniform, vec4 value) {
        glUniform4f(uniform, value.x, value.y, value.z, value.w);
    }

    void setUniform(GLint uniform, mat4 value) {
        glUniformMatrix4fv(uniform, 1, GL_TRUE, value.value_ptr);
    }
}