#version 400 compatibility

//--// Outputs //----------------------------------------------------------------------------------------//

out vec4 color;

//--// Inputs //-----------------------------------------------------------------------------------------//

layout (location = 0) in vec4 vertexPosition;
layout (location = 3) in vec4 vertexColor;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform mat4 gbufferProjection;

//--// Functions //--------------------------------------------------------------------------------------//

vec4 initPosition() {
	return gl_ModelViewMatrix * vertexPosition;
}

void main() {
	gl_Position = gbufferProjection * initPosition();

	color = vertexColor;
}
