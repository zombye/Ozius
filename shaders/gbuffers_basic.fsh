#version 400

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:012 */

layout (location = 0) out vec4 data0;
layout (location = 1) out vec4 data1;
layout (location = 2) out vec4 data2;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec4 color;

//--// Functions //--------------------------------------------------------------------------------------//

void main() {
	data0 = color; data0.a = 1.0;
	data1 = vec4(0.0);
	data2 = vec4(1.0);
}
