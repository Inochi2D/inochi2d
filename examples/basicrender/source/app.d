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
	initInochi2D();

	glLineWidth(4);

	

	Camera camera = new Camera();

	Texture tex = new Texture("test.png");

	DynMesh mesh = new DynMesh(tex, MeshData.createQuadMesh(vec2i(tex.width, tex.height), vec4(0, 0, 1, 1), vec2i(31, 15)));
	mesh.transform.position = vec2(32, 32);

	glClearColor(0, 0, 0, 1);
	int width, height;
	double mx, my;
	double lmx, lmy;

	vec2[] opts = mesh.originPoints();
	size_t center = mesh.points.length/2;

	size_t* selected;
	vec2 selectedStartPos;

	// Render loop
	while(!glfwWindowShouldClose(window)) {
		glfwGetWindowSize(window, &width, &height);
		glfwGetCursorPos(window, &mx, &my);
		
		float trmx = mx-mesh.transform.position.x;
		float trmy = my-mesh.transform.position.y;

		float mxdiff = lmx-mx;
		float mydiff = lmy-my;

		if (glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_RIGHT) == GLFW_PRESS) {
			mesh.resetDeform();
		}

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

		//mesh.points[center] = dampen(mesh.points[center], vec2(mx-mesh.transform.position.x, my-mesh.transform.position.y), 0.05);

		// foreach(i; 0..mesh.points.length) {
		// 	float shakeX = (uniform01()*2)-1;
		// 	float shakeY = (uniform01()*2)-1;
		// 	mesh.points[i] = opts[i] + vec2(shakeX*8, shakeY*8);
		// }
		mesh.mark();

		// Clear color and depth buffer
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glViewport(0, 0, width, height);

		// Where we render our puppet
		// TODO: render our puppet
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

Puppet createPuppet() {
	return new Puppet();
}