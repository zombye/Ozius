#version 420 compatibility

//--// Outputs //----------------------------------------------------------------------------------------//

out vec3 positionView;

out mat3 tbnMatrix;
out vec4 tint;
out vec2 baseUV;
out vec2 lmUV;

//--// Inputs //-----------------------------------------------------------------------------------------//

layout (location = 0)  in vec4 vertexPosition;
layout (location = 2)  in vec3 vertexNormal;
layout (location = 3)  in vec4 vertexColor;
layout (location = 8)  in vec2 vertexUV;
layout (location = 9)  in vec2 vertexLightmap;
layout (location = 10) in vec4 vertexMetadata;
layout (location = 11) in vec2 quadMidUV;
layout (location = 12) in vec4 vertexTangent;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform float frameTimeCounter;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferProjection;
uniform mat4 gbufferModelViewInverse;

uniform sampler2D noisetex;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"

#include "/lib/util/sumof.glsl"

//--//

#include "/lib/gbuffers/initPosition.vsh"

mat3 calculateTBN() {
	vec3 tangent = normalize(vertexTangent.xyz);

	return mat3(
		gl_NormalMatrix * tangent,
		gl_NormalMatrix * cross(tangent, vertexNormal) * sign(vertexTangent.w),
		gl_NormalMatrix * vertexNormal
	);
}

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
	positionView = gl_Position.xyz;
	vec4 positionLocal = gbufferModelViewInverse * gl_Position;
	vec4 positionWorld = positionLocal + vec4(cameraPosition, 0.0);
	calculateDisplacement(positionWorld.xyz);
	positionLocal = positionWorld - vec4(cameraPosition, 0.0);
	gl_Position = gbufferModelView * positionLocal;
	gl_Position = gl_ProjectionMatrix * gl_Position;

	tbnMatrix = calculateTBN();
	tint      = vertexColor;
	baseUV    = vertexUV;
	lmUV      = vertexLightmap / 256.0;
}
