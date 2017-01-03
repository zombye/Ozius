#version 400 compatibility

//--// Outputs //----------------------------------------------------------------------------------------//

out mat3 tbnMatrix;
out vec4 tint;
out vec2 texCoord;
out vec2 lmCoord;

//--// Inputs //-----------------------------------------------------------------------------------------//

layout (location = 0)  in vec4 vertexPosition;
layout (location = 2)  in vec3 vertexNormal;
layout (location = 3)  in vec4 vertexColor;
layout (location = 8)  in vec2 vertexUV;
layout (location = 9)  in vec2 vertexLightmap;
layout (location = 12) in vec4 vertexTangent;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform mat4 gbufferProjection;

//--// Functions //--------------------------------------------------------------------------------------//

vec4 initPosition() {
	return gl_ModelViewMatrix * vertexPosition;
}

mat3 calculateTBN() {
	vec3 tangent = normalize(vertexTangent.xyz);

	return mat3(
		gl_NormalMatrix * tangent,
		gl_NormalMatrix * cross(vertexNormal, tangent) * sign(vertexTangent.w),
		gl_NormalMatrix * vertexNormal
	);
}

void main() {
	gl_Position = gbufferProjection * initPosition();

	tbnMatrix = calculateTBN();
	tint      = vertexColor;
	texCoord  = vertexUV;
	lmCoord   = vertexLightmap;
}
