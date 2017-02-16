#version 420

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:01 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec3 normal;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec4 tint;
in vec2 baseUV;
in vec3 vertNormal;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform sampler2D base;

//--// Functions //--------------------------------------------------------------------------------------//

void main() {
	color  = texture(base, baseUV) * tint;
	color.rgb = pow(color.rgb, vec3(2.2));
	normal = vertNormal * 0.5 + 0.5;
}
