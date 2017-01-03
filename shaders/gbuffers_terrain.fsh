#version 420

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:012 */

layout (location = 0) out vec4 data0;
layout (location = 1) out vec4 data1;
layout (location = 2) out vec4 data2;

//--// Inputs //-----------------------------------------------------------------------------------------//

in mat3 tbnMatrix;
in vec4 tint;
in vec2 texCoord;
in vec2 lmCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform float wetness;

uniform sampler2D albedo;
uniform sampler2D specular;

//--// Functions //--------------------------------------------------------------------------------------//

vec2 packNormal(vec3 normal) {
	return normal.xy * inversesqrt(normal.z * 8.0 + 8.0) + 0.5;
}

void main() {
	vec4 albedoTex = texture(albedo, texCoord) * tint;
	if (albedoTex.a < 0.102) discard; // ~ 26 / 255

	vec4 specularTex = texture(specular, texCoord);

	specularTex.b = mix(specularTex.b, specularTex.b * 0.08 + 0.02, wetness);
	specularTex.a = mix(specularTex.a, specularTex.a * 0.98 + 0.02, wetness);

	data0 = albedoTex;
	data1 = specularTex;
	data2.xy = packNormal(tbnMatrix[2]);
	data2.zw = lmCoord;
}
