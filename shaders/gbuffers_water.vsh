#version 420 compatibility

//--// Outputs //----------------------------------------------------------------------------------------//

out vec4 tint;
out vec2 baseUV; 

//--// Inputs //-----------------------------------------------------------------------------------------//

layout (location = 0) in vec4 vertexPosition;
layout (location = 3) in vec4 vertexColor;
layout (location = 8) in vec2 vertexUV;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/gbuffers/initPosition.vsh"

void main() {
	gl_Position = initPosition();
	gl_Position = gl_ProjectionMatrix * gl_Position;

	tint   = vertexColor;
	baseUV = vertexUV;
}
