#version 420 compatibility

//--// Outputs //----------------------------------------------------------------------------------------//

out vec4 tint;
out vec2 baseUV;

//--// Inputs //-----------------------------------------------------------------------------------------//

layout (location = 0)  in vec4 vertexPosition;
layout (location = 3)  in vec4 vertexColor;
layout (location = 8)  in vec2 vertexUV;
layout (location = 9)  in vec2 vertexLightmap;
layout (location = 10) in vec4 vertexMetadata;
layout (location = 11) in vec2 quadMidUV;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform float frameTimeCounter;
uniform float rainStrength;

uniform vec3 cameraPosition;

uniform mat4 shadowModelView, shadowProjection;
uniform mat4 shadowModelViewInverse;

uniform sampler2D noisetex;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"

//--//

#include "/lib/gbuffers/initPosition.vsh"

//--//

vec2 pcb(vec2 coord, sampler2D sampler) {
	ivec2 res = textureSize(sampler, 0);
	coord *= res;

	vec2 fr = fract(coord);
	coord = floor(coord) + (fr * fr * (3.0 - 2.0 * fr)) + 0.5;

	return coord / res;
}
vec4 textureSmooth(sampler2D sampler, vec2 coord) {
	return texture(sampler, pcb(coord, sampler));
}

#include "/lib/gbuffers/displacement.vsh"

//--//

void main() {
	gl_Position = initPosition();
	vec4 positionLocal = shadowModelViewInverse * gl_Position;
	vec4 positionWorld = positionLocal + vec4(cameraPosition, 0.0);
	calculateDisplacement(positionWorld.xyz);
	positionLocal = positionWorld - vec4(cameraPosition, 0.0);
	gl_Position = shadowModelView * positionLocal;
	gl_Position = gl_ProjectionMatrix * gl_Position;

	gl_Position.xy /= 1.0 + length(gl_Position.xy);
	gl_Position.z  *= 0.25;

	tint   = vertexColor;
	baseUV = vertexUV;
}
