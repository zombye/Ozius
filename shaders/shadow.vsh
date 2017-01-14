#version 420 compatibility

//--// Outputs //----------------------------------------------------------------------------------------//

out vec4 tint;
out vec2 baseUV;

//--// Inputs //-----------------------------------------------------------------------------------------//

layout (location = 0)  in vec4 vertexPosition;
layout (location = 3)  in vec4 vertexColor;
layout (location = 8)  in vec2 vertexUV;

//--// Uniforms //---------------------------------------------------------------------------------------//

//uniform mat4 shadowProjection;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/gbuffers/initPosition.vsh"

void main() {
	gl_Position     = gl_ProjectionMatrix * initPosition();
	gl_Position.xy /= 1.0 + length(gl_Position.xy);
	gl_Position.z  *= 0.25;

	tint   = vertexColor;
	baseUV = vertexUV;
}
