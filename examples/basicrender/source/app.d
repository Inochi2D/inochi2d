/*
    Inochi2D Example and Testbed

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
import std.stdio;
import bindbc.glfw;
import bindbc.opengl;
import inochi2d;
import std.stdio;
import std.random;

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

	// Initialize Inochi2D
	initInochi2D(cast(double function())glfwGetTime);
	
	// Create a DynMesh
	Camera camera = new Camera();
	Texture tex = new Texture("test.png");
	DynMesh mesh = new DynMesh(tex, MeshData.createQuadMesh(vec2i(tex.width, tex.height), vec4(0, 0, 1, 1), vec2i(31, 15)));
	mesh.transform.position = vec2(32, 32);

	// Might as well set the clear color to black
	// Change values here (range 0-1) to change RGB background color
	glClearColor(0, 0, 0, 1);


	size_t* selected;
	vec2 selectedStartPos;
	int width, height;
	double mx, my;
	double lmx, lmy;

	while(!glfwWindowShouldClose(window)) {

		// Update Inochi2D
		updateInochi2D();

		glfwGetWindowSize(window, &width, &height);
		glfwGetCursorPos(window, &mx, &my);
		
		float trmx = mx-mesh.transform.position.x;
		float trmy = my-mesh.transform.position.y;

		float mxdiff = lmx-mx;
		float mydiff = lmy-my;

		// Reset deform code
		if (glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_RIGHT) == GLFW_PRESS) {
			mesh.resetDeform();
		}

		// Mouse drag code
		if (glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS) {
			if (selected is null) {
				foreach(i, point; mesh.points) {
					float dist = point.distance(vec2(trmx, trmy));
					if (dist < 16) {
						selected = new size_t(i);
						selectedStartPos = vec2(point);
						break;
					}
				}
			}

			if (selected !is null) {
				mesh.pull(*selected, vec2(mxdiff, mydiff), 256f);
			}
		} else {
			selected = null;
		}

		// IMPORTANT: When a dynamic mesh gets deformed it needs to be marked for updating
		// Use the DynMesh.mark function to do this.
		mesh.mark();

		// Clear color and depth buffer
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glViewport(0, 0, width, height);

		// Draw our DynMesh
		mesh.draw(camera.matrix(width, height));
		mesh.drawDebug(camera.matrix(width, height));
		mesh.drawDebug!(true)(camera.matrix(width, height), 2);

		// Buffer and event handling
		glfwSwapBuffers(window);
		glfwPollEvents();

		lmx = mx;
		lmy = my;
	}

	// Post cleanup
	glfwDestroyWindow(window);
	glfwTerminate();
}