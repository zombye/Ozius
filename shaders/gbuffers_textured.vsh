#version 420 compatibility

//--// Configuration //----------------------------------------------------------------------------------//

#define TEMPORAL_AA

//--// Outputs //----------------------------------------------------------------------------------------//

out mat3 tbnMatrix;
out vec4 tint;
out vec2 baseUV;
out float blockID;

//--// Inputs //-----------------------------------------------------------------------------------------//

layout (location = 0)  in vec4 vertexPosition;
layout (location = 2)  in vec3 vertexNormal;
layout (location = 3)  in vec4 vertexColor;
layout (location = 8)  in vec2 vertexUV;
layout (location = 10) in vec4 vertexMetadata;
layout (location = 12) in vec4 vertexTangent;

//--// Uniforms //---------------------------------------------------------------------------------------//

#ifdef TEMPORAL_AA
uniform int frameCounter;

uniform float viewWidth, viewHeight;
#endif

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/util/hammersley.glsl"

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

void main() {
	gl_Position = initPosition();
	gl_Position = gl_ProjectionMatrix * gl_Position;

	tbnMatrix = calculateTBN();
	tint      = vertexColor;
	baseUV    = vertexUV;
	blockID   = vertexMetadata.x;

	#ifdef TEMPORAL_AA
	gl_Position.xy += ((hammersley(uint(mod(frameCounter, 16)), 16) * 2.0 - 1.0) / vec2(viewWidth, viewHeight)) * gl_Position.w;
	#endif
}
