#include "inochi2d.h"
#include <GL/glew.h>
#include <GL/glext.h>
#include <GL/gl.h>
#include <SDL3/SDL_error.h>
#include <SDL3/SDL_events.h>
#include <SDL3/SDL_init.h>
#include <SDL3/SDL_iostream.h>
#include <SDL3/SDL_oldnames.h>
#include <SDL3/SDL_opengl.h>
#include <SDL3/SDL_hints.h>
#include <SDL3/SDL_timer.h>
#include <SDL3/SDL_video.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

const char vertex[] = {
	#embed "shaders/shader.vert"
	, '\0'
};

const char fragment[] = {
	#embed "shaders/shader.frag"
	, '\0'
};

// A matrix container.
typedef union mat4 {
	float data[16];
	struct {
		float m0[4];
		float m1[4];
		float m2[4];
		float m3[4];
	};
} mat4_t;

// This allows us to get messages from Inochi2D during loading.
void message_sink(const char *msg, const char *file, uint32_t line) {
	printf("%s(%d): %s\n", file, line, msg);
}

// Loads the model and sets up the sinks.
static io_sink_t sink;
in_puppet_t *load_model(const char *path) {
	sink.info = &message_sink;
	sink.warning = &message_sink;
	sink.error = &message_sink;
	return in_puppet_load(path, &sink);
}

// Loads a texture from a model and returns its GL id. 
GLuint load_model_texture(in_texture_t* texture) {
	GLuint tid;

	if (texture) {

		// Make OpenGL texture.
		glGenTextures(1, &tid);
		glBindTexture(GL_TEXTURE_2D, tid);
		glTexImage2D(
			GL_TEXTURE_2D, 
			0, 
			GL_RGBA, 
			in_texture_get_width(texture), 
			in_texture_get_height(texture), 
			0, 
			GL_RGBA, 
			GL_UNSIGNED_BYTE,
			in_texture_get_pixels(texture)
		);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
		glGenerateMipmap(GL_TEXTURE_2D);
	}

	return tid;
}

// Gets the error log of a shader, or null if there was no errors.
char *get_shader_log(GLuint shader) {
	GLenum status;
	glGetShaderiv(shader, GL_COMPILE_STATUS, (void*)&status);

	if (status == GL_FALSE) {
		GLsizei logLength;
		glGetShaderiv(shader, GL_INFO_LOG_LENGTH, (void*)&logLength);

		char *msg = (char*)malloc(logLength);
		glGetShaderInfoLog(shader, logLength, &logLength, msg);
		return msg;
	}
	return NULL;
}

// Gets the error log of a shader, or null if there was no errors.
char *get_program_log(GLuint program) {
	GLenum status;
	glGetProgramiv(program, GL_LINK_STATUS, (void*)&status);

	if (status == GL_FALSE) {
		GLsizei logLength;
		glGetProgramiv(program, GL_INFO_LOG_LENGTH, (void*)&logLength);

		char *msg = (char*)malloc(logLength);
		glGetProgramInfoLog(program, logLength, &logLength, msg);
		return msg;
	}
	return NULL;
}

// Creates a shader.
GLuint create_shader(const char * name, const char *source, GLenum type) {
	GLuint shader = glCreateShader(type);
	glShaderSource(shader, 1, &source, NULL);
	glCompileShader(shader);

	char *msg = get_shader_log(shader);
	if (msg) {
		fprintf(stderr, "%s: %s\n", name, msg);
		exit(EINVAL);
	}
	return shader;
}

GLuint link_shaders(GLuint vertex, GLuint fragment) {
	GLuint program = glCreateProgram();
	glAttachShader(program, vertex);
	glAttachShader(program, fragment);
	glLinkProgram(program);

	char *msg = get_program_log(program);
	if (msg) {
		fprintf(stderr, "%s\n", msg);
		exit(EINVAL);
	}
	return program;
}

// Makes an identity matrix.
mat4_t make_identity() {
	static const float __identity[] = { 
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1,
	};

	mat4_t m;
	memcpy(&m, __identity, sizeof(__identity));
	return m;
}

// Makes a zero matrix.
mat4_t make_zero() {
	static const float __zero[] = { 
		0, 0, 0, 0,
		0, 0, 0, 0,
		0, 0, 0, 0,
		0, 0, 0, 0,
	};

	mat4_t m;
	memcpy(&m, __zero, sizeof(__zero));
	return m;
}

// Makes an orthographic matrix.
mat4_t make_ortho(float left, float right, float bottom, float top, float near, float far) {
	mat4_t m = make_identity();

    float sLength = 1.0 / (right - left);
    float sHeight = 1.0 / (top   - bottom);
    float sDepth  = 1.0 / (far   - near);

    m.m0[0] = 2.0 * sLength;
    m.m1[1] = 2.0 * sHeight;
    m.m2[2] = -sDepth;
    m.m2[3] = -near * sDepth;
    m.m3[3] = 1.0;
	return m;
}

// Makes a scaling matrix.
mat4_t make_scale(float x, float y, float z) {
	mat4_t m = make_identity();
	m.m0[0] = x;
	m.m1[1] = y;
	m.m2[2] = z;
	return m;
}

// Makes a scaling matrix.
mat4_t make_translation(float x, float y, float z) {
	mat4_t m = make_identity();
	m.m0[3] = x;
	m.m1[3] = y;
	m.m2[3] = z;
	return m;
}

// Multiplies the matrix on the left with the matrix on the right.
mat4_t mat_multiply(mat4_t lhs, mat4_t rhs) {
	mat4_t result = make_zero();

	for (int r = 0; r < 4; r++) {
		for (int c = 0; c < 4; c++) {
			for (int c2 = 0; c2 < 4; c2++) {
				result.data[(r*4)+c] += lhs.data[(r*4)+c2] * rhs.data[(c2*4)+c];
			}
		}
	}
	return result;
}

void set_blend_mode(in_blend_mode_t mode) {
	switch(mode) {
		
	// If the advanced blending extension is not supported, force to Normal blending
	default:
		glBlendEquation(GL_FUNC_ADD);
		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;

	case IN_BLEND_MODE_NORMAL: 
		glBlendEquation(GL_FUNC_ADD);
		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;

	case IN_BLEND_MODE_MULTIPLY: 
		glBlendEquation(GL_FUNC_ADD);
		glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA); break;

	case IN_BLEND_MODE_SCREEN:
		glBlendEquation(GL_FUNC_ADD);
		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR); break;

	case IN_BLEND_MODE_LIGHTEN:
		glBlendEquation(GL_MAX);
		glBlendFunc(GL_ONE, GL_ONE); break;

	case IN_BLEND_MODE_COLOR_DODGE:
		glBlendEquation(GL_FUNC_ADD);
		glBlendFunc(GL_DST_COLOR, GL_ONE); break;

	case IN_BLEND_MODE_LINEAR_DODGE:
		glBlendEquation(GL_FUNC_ADD);
		glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_COLOR, GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;
		
	case IN_BLEND_MODE_ADD_GLOW:
		glBlendEquation(GL_FUNC_ADD);
		glBlendFuncSeparate(GL_ONE, GL_ONE, GL_ONE, GL_ONE_MINUS_SRC_ALPHA); break;

	case IN_BLEND_MODE_SUBTRACT:
		glBlendEquationSeparate(GL_FUNC_REVERSE_SUBTRACT, GL_FUNC_ADD);
		glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ONE); break;

	case IN_BLEND_MODE_EXCLUSION:
		glBlendEquation(GL_FUNC_ADD);
		glBlendFuncSeparate(GL_ONE_MINUS_DST_COLOR, GL_ONE_MINUS_SRC_COLOR, GL_ONE, GL_ONE); break;

	case IN_BLEND_MODE_INVERSE:
		glBlendEquation(GL_FUNC_ADD);
		glBlendFunc(GL_ONE_MINUS_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA); break;
	
	case IN_BLEND_MODE_DESTINATION_IN:
		glBlendEquation(GL_FUNC_ADD);
		glBlendFunc(GL_ZERO, GL_SRC_ALPHA); break;

	case IN_BLEND_MODE_SOURCE_IN:
		glBlendEquation(GL_FUNC_ADD);
		glBlendFunc(GL_DST_ALPHA, GL_ONE_MINUS_SRC_ALPHA); break;

	case IN_BLEND_MODE_SOURCE_OUT:
		glBlendEquation(GL_FUNC_ADD);
		glBlendFunc(GL_ZERO, GL_ONE_MINUS_SRC_ALPHA); break;
	}
}

int main(int argc, char *argv[]) {

	// Handle no args.
	if (argc <= 1) {
		printf("%s <model path>\n", argv[0]);
		return EINVAL;
	}

	in_puppet_t *puppet = load_model(argv[1]);
	if (!puppet) {
		fprintf(stderr, "Failed to load %s...\n", argv[1]);
		return ENOENT;
	}




	//
	// 		Initialization
	//
	int width, height;

	// GLEW only supports X11 by default so we force
	// the X11 video driver on init.
	SDL_SetHint(SDL_HINT_VIDEO_DRIVER, "x11");
	if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
		fprintf(stderr, "SDL: %s\n", SDL_GetError());
		return ENOENT;
	}

	// Create OpenGL 3.2 window.
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
	SDL_Window *window = SDL_CreateWindow("Example Renderer", 640, 480, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
	SDL_GLContext glctx = SDL_GL_CreateContext(window);
	if (glctx == NULL) {
		fprintf(stderr, "SDL: %s!...\n", SDL_GetError());
		return EINVAL;
	}

	// Initialize GLEW
	GLenum glewError = glewInit();
	if (glewError != GLEW_OK) {
		fprintf(stderr, "GLEW Error: %d (%s)!\n", glewError, glewGetErrorString(glewError));
		return EINVAL;
	}




	//
	// 		Model Loading
	//

	// Load model data.
	uint32_t textureCount;
	in_texture_cache_t *cache = in_puppet_get_texture_cache(puppet);
	in_texture_t** textures = in_texture_cache_get_textures(cache, &textureCount);
	for(int i = 0; i < textureCount; i++) {

		// Load OpenGL texture and store it into the resource ID.
		size_t id = load_model_texture(textures[i]);
		in_resource_set_id((in_resource_t*)textures[i], (void*)id);
	}

	// Create VAO
	GLuint vao;

	glGenVertexArrays(1, &vao);
	glBindVertexArray(vao);

	// Create buffers.
	GLuint vbo;
	GLuint ibo;
	GLuint ubo;
	glGenBuffers(1, &vbo);
	glGenBuffers(1, &ibo);
	glGenBuffers(1, &ubo);

	// Bind buffers.
	glBindBuffer(GL_UNIFORM_BUFFER, ubo);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);


	// Create shader(s)
	GLuint vtx = create_shader("vertex", vertex, GL_VERTEX_SHADER);
	GLuint frg = create_shader("fragment", fragment, GL_FRAGMENT_SHADER);
	GLuint shader = link_shaders(vtx, frg);

	// Get uniforms.
	GLint mtx_mv = glGetUniformLocation(shader, "modelViewMatrix");

	// Create remaining rendering objects.
	uint64_t lastTime = 0, currTime = 0;
	float timef = 0;
	mat4_t camera;
	in_drawlist_t *drawlist = in_puppet_get_drawlist(puppet);

	// Setup consistent GL state.
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(0, 2, GL_FLOAT, false, sizeof(in_vtxdata_t), NULL);
	glEnableVertexAttribArray(1);
	glVertexAttribPointer(1, 2, GL_FLOAT, false, sizeof(in_vtxdata_t), (void*)8);
	glDisable(GL_CULL_FACE);
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_STENCIL_TEST);
	glEnable(GL_BLEND);

	bool closeRequested = false;
	while (!closeRequested) {
		currTime = SDL_GetTicks();
		float deltaTime = ((double)currTime-(double)lastTime)*0.001;
		timef += deltaTime;
		SDL_GetWindowSizeInPixels(window, &width, &height);




		//
		// 		Handle window events.
		//
		SDL_Event ev;
		while(SDL_PollEvent(&ev)) {
			switch(ev.type) {
			case SDL_EVENT_QUIT:
				closeRequested = true;
				break;

			default:
				break;
			}
		}




		//
		// 		Render scene.
		//

		in_puppet_update(puppet, deltaTime);
		in_puppet_draw(puppet, deltaTime);




		// Upload changed vertex and index data to GPU.
		// NOTE:	This approach is not optimal, better to use glBufferSubData
		// 			but this example is meant to be naïve.
		uint32_t dataLength;
		void *indices = in_drawlist_get_index_data(drawlist, &dataLength);
		void *vertices = in_drawlist_get_vertex_data(drawlist, &dataLength);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, dataLength, indices, GL_DYNAMIC_DRAW);

		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, dataLength, vertices, GL_DYNAMIC_DRAW);




		// Begin frame by resetting state.
		glViewport(0, 0, width, height);
		glClearColor(0, 0, 0, 0);
		glClear(GL_COLOR_BUFFER_BIT);

		// Setup camera.
		camera = mat_multiply(
			mat_multiply(															// PROJECTION
				make_scale(0.125, 0.125, 1),
				make_ortho(0, width, height, 0, 0.0001, 100)
			),
			make_translation(sinf(timef)*(width/2.0), cosf(timef)*(height/2.0), 0) 	// VIEW
		);
		
		// TODO: Finish Render Loop
		uint32_t cdepth = 0;
		uint32_t mdepth = 0;
		uint32_t cmdCount = 0;
		in_drawcmd_t* cmds = in_drawlist_get_commands(drawlist, &cmdCount);
		for (int i = 0; i < cmdCount; i++) {

			switch(cmds[i].state) {
			case IN_DRAW_STATE_NORMAL:
				
				// We skip composites in this ultra basic renderer.
				if (cdepth > 0)
					break;

				// NOTE: 	We only render with the albedo texture in this example.
				//			The albedo texture is reserved into slot 0.
				size_t id = (size_t)in_resource_get_id((in_resource_t*)cmds[i].sources[0]);
				glBindTexture(GL_TEXTURE_2D, id);

				size_t idxOffset = (size_t)(cmds[i].idxOffset)*4;

				// Set up render state.
				glUseProgram(shader);
				glUniformMatrix4fv(mtx_mv, 1, GL_TRUE, camera.data);
				set_blend_mode(cmds[i].blendMode);
				glDrawElementsBaseVertex(
					GL_TRIANGLES,
					cmds[i].elemCount,
					GL_UNSIGNED_INT,
					(void*)idxOffset,
					cmds[i].vtxOffset
				);
				break;

			case IN_DRAW_STATE_DEFINE_MASK:
				break;
				
			case IN_DRAW_STATE_PUSH_MASK:
				mdepth++;
				break;
				
			case IN_DRAW_STATE_POP_MASK:
				mdepth--;
				break;
				
			case IN_DRAW_STATE_COMPOSITE_BEGIN:
				cdepth++;
				break;
				
			case IN_DRAW_STATE_COMPOSITE_END:
				cdepth--;
				break;

			default:
				break;
			}
		}

		// Swap window.
		SDL_GL_SwapWindow(window);
		lastTime = currTime;
	}

	in_puppet_free(puppet);
	printf("Byebye!\n");
	return 0;
}