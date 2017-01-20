#version 420

//--// Outputs //----------------------------------------------------------------------------------------//

out vec2 fragCoord;

out float exposure;

//--// Inputs //-----------------------------------------------------------------------------------------//

layout (location = 0) in vec4 vertexPosition;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform sampler2D colortex5;

//--// Functions //--------------------------------------------------------------------------------------//

void main() {
	gl_Position = vertexPosition * 2.0 - 1.0;
	fragCoord = vertexPosition.xy;

	exposure = 1.0 / dot(textureLod(colortex5, vec2(0.5), 100).rgb, vec3(1.0));
}
