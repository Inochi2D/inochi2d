/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.shader;
import inochi2d.core.math;
import std.string;
import bindbc.opengl;

/**
    The type of a shader uniform
*/
enum ShaderUniformType {
    f32     = GL_FLOAT,
    vec2    = GL_FLOAT_VEC2,
    vec3    = GL_FLOAT_VEC3,
    vec4    = GL_FLOAT_VEC4,
    i32     = GL_INT,
    ivec2   = GL_INT_VEC2,
    ivec3   = GL_INT_VEC3,
    ivec4   = GL_INT_VEC4,
    boolean = GL_BOOL,
    mat2    = GL_FLOAT_MAT2,
    mat3    = GL_FLOAT_MAT3,
    mat4    = GL_FLOAT_MAT4,

    // Special types
    texture1D   = GL_SAMPLER_1D,
    texture2D   = GL_SAMPLER_2D,
    texture3D   = GL_SAMPLER_3D,
    textureCube = GL_SAMPLER_CUBE,
}

/**
    A shader
*/
class Shader {
private:
    string fragSource;
    string vertSource;
    string name;
    string[string] defines;

    GLuint shaderProgram;
    GLuint fragShader;
    GLuint vertShader;

    string definesToStr() {
        import std.format : format;

        string out_;
        foreach(key, value; defines) {
            out_ ~= "#define %s %s\n".format(key, value.length > 0 ? value : "");
        }
        return out_;
    }

    GLuint compileShader(string defines, string source, GLenum shaderType) {

        // Create C-compatible array.
        const(char)*[2] srcArr = [
            defines.ptr,
            source.ptr
        ];

        const(GLint)[2] srcLength = [
            cast(GLint)defines.length,
            cast(GLint)source.length
        ];

        auto shader = glCreateShader(shaderType);
        glShaderSource(shader, cast(int)srcArr.length, srcArr.ptr, srcLength.ptr);
        glCompileShader(shader);

        string shaderTypeName = shader == GL_VERTEX_SHADER ? "vertex" : "fragment";
        int compileStatus;
        glGetShaderiv(shader, GL_COMPILE_STATUS, &compileStatus);
        if (compileStatus == GL_FALSE) {

            // Get the length of the error log
            GLint logLength;
            glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
            if (logLength > 0) {

                // Fetch the error log
                char[] log = new char[logLength];
                glGetShaderInfoLog(shader, logLength, null, log.ptr);

                throw new Exception("Compilation error for %s->%s:\n\n%s".format(name, shaderTypeName, cast(string)log));
            }
        }
        return shader;
    }

    void compileShaders() {
        this.destroyProgram();

        string defstr = definesToStr();

        // Compile shaders
        vertShader = compileShader(defstr, vertSource, GL_VERTEX_SHADER);
        fragShader = compileShader(defstr, fragSource, GL_FRAGMENT_SHADER);

        // Attach and link them
        linkProgram();
    }

    void linkProgram() {
        shaderProgram = glCreateProgram();
        glAttachShader(shaderProgram, vertShader);
        glAttachShader(shaderProgram, fragShader);
        glLinkProgram(shaderProgram);

        int linkStatus;
        glGetProgramiv(shaderProgram, GL_LINK_STATUS, &linkStatus);
        if (linkStatus == GL_FALSE) {

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
    }

    void destroyProgram() {
        if (shaderProgram != 0) {
            glDetachShader(shaderProgram, vertShader);
            glDetachShader(shaderProgram, fragShader);
            glDeleteProgram(shaderProgram);
            
            glDeleteShader(fragShader);
            glDeleteShader(vertShader);

            shaderProgram = 0;
            fragShader = 0;
            vertShader = 0;
        }
    }

public:

    /**
        Destructor
    */
    ~this() {
        this.destroyProgram();
    }

    /**
        Creates a new shader object from source
    */
    this(string name, string vertex, string fragment) {
        this.name = name;
        this.vertSource = vertex;
        this.fragSource = fragment;
    }

    /**
        (Re-) compiles the shader.
    */
    ref auto Shader compile() {
        this.compileShaders();
        return this;
    }

    /**
        Sets a compile-time variable.
    */
    ref auto Shader define(T)(string key, T value) {
        import std.conv : text;
        this.defines[key] = value.text;
        return this;
    }

    /**
        Sets a compile-time variable if a condition is met.
    */
    ref auto Shader defineIf(T, Y)(Y condition, string key, T value) {
        if (condition)
            this.define(key, value);
        
        return this;
    }

    /**
        Sets a compile-time variable.
    */
    ref auto Shader define(string key) {
        this.defines[key] = null;
        return this;
    }

    /**
        Sets a compile-time variable if a condition is met.
    */
    ref auto Shader defineIf(Y)(Y condition, string key) {
        if (condition)
            this.define(key);
        
        return this;
    }

    /**
        Removes a compile-time variable.
    */
    ref auto Shader remove(string key) {
        this.defines.remove(key);
        return this;
    }

    /**
        Tells OpenGL to use the shader
    */
    void use() {
        glUseProgram(shaderProgram);
    }

    /**
        Gets the location of a uniform value

        Params:
            name = The name of the uniform to get
        
        Returns:
            The GLSL ID of the uniform.
    */
    GLint getUniformLocation(string name) {
        return glGetUniformLocation(shaderProgram, name.ptr);
    }

    /**
        Sets a uniform
    */
    void setUniform(GLint uniform, bool value) {
        glUniform1i(uniform, cast(int)value);
    }

    /// ditto
    void setUniform(GLint uniform, int value) {
        glUniform1i(uniform, value);
    }

    /// ditto
    void setUniform(GLint uniform, float value) {
        glUniform1f(uniform, value);
    }

    /// ditto
    void setUniform(GLint uniform, vec2 value) {
        glUniform2f(uniform, value.x, value.y);
    }

    /// ditto
    void setUniform(GLint uniform, vec3 value) {
        glUniform3f(uniform, value.x, value.y, value.z);
    }

    /// ditto
    void setUniform(GLint uniform, vec4 value) {
        glUniform4f(uniform, value.x, value.y, value.z, value.w);
    }

    /// ditto
    void setUniform(GLint uniform, mat4 value) {
        glUniformMatrix4fv(uniform, 1, GL_TRUE, value.ptr);
    }
}