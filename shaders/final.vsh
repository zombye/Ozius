#version 420

//--// Outputs //----------------------------------------------------------------------------------------//

out vec2 fragCoord;

//--// Inputs //-----------------------------------------------------------------------------------------//

layout (location = 0) in vec2 vertexPosition;
layout (location = 8) in vec2 vertexUV;

//--// Functions //--------------------------------------------------------------------------------------//

void main() {
	gl_Position.xy = vertexPosition * 2.0 - 1.0;
	gl_Position.zw = vec2(1.0);

	fragCoord = vertexUV;
}
