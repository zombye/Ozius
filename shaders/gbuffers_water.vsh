#version 400 compatibility

//--// Outputs //----------------------------------------------------------------------------------------//

out vec4 tint;
out vec2 texCoord;

//--// Inputs //-----------------------------------------------------------------------------------------//

layout (location = 0) in vec4 vertexPosition;
layout (location = 3) in vec4 vertexColor;
layout (location = 8) in vec2 vertexUV;

//--// Functions //--------------------------------------------------------------------------------------//
vec4 initPosition() {
	return gl_ModelViewMatrix * vertexPosition;
}

void main() {
	gl_Position = gl_ProjectionMatrix * initPosition();

	tint     = vertexColor;
	texCoord = vertexUV;
}
