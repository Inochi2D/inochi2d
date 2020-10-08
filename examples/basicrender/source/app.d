import std.stdio;
import bindbc.glfw;
import bindbc.opengl;

void main()
{
	// Set up GLFW
	loadGLFW();
	glfwInit();
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);

	// Create Window and load OpenGL
	GLFWwindow* window = glfwCreateWindow(640, 480, "Inochi Test Window", null, null);
	glfwMakeContextCurrent(window);	
	loadOpenGL();

	// Render loop
	while(!glfwWindowShouldClose(window)) {
		
		// Where we render our puppet
		// TODO: render our puppet

		// Buffer and event handling
		glfwSwapBuffers(window);
		glfwPollEvents();
	}

	// Post cleanup
	glfwDestroyWindow(window);
	glfwTerminate();
}