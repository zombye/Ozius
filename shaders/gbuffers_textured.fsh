#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:01 */

layout (location = 0) out vec4 packedMaterial;
layout (location = 1) out vec4 packedData;

//--// Inputs //-----------------------------------------------------------------------------------------//

in mat3 tbnMatrix;
in vec4 tint;
in vec2 baseUV;
in vec2 lmUV;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform vec3 shadowLightPosition;

uniform sampler2D base;
uniform sampler2D normals;
uniform sampler2D specular;

//--// Functions //--------------------------------------------------------------------------------------//

vec3 getNormal(vec2 coord) {
	vec3 tsn = texture(normals, coord).rgb;
	tsn.xy += 0.5 / 255.0; // Need to add this for correct results.
	return tbnMatrix * normalize(tsn * 2.0 - 1.0);
}

#include "/lib/util/packing/normal.glsl"

void main() {
	vec4 albedo = texture(base, baseUV) * tint;
	if (albedo.a < 0.102) discard; // ~ 26 / 255

	vec4 spec = texture(specular, baseUV);

	//--//

	packedMaterial.r = uintBitsToFloat(packUnorm4x8(vec4(albedo.rgb, sign(dot(tbnMatrix[2], shadowLightPosition)))));
	packedMaterial.g = uintBitsToFloat(packUnorm4x8(spec));
	packedMaterial.b = uintBitsToFloat(packUnorm4x8(vec4(0.0, 0.0, 0.0, 1.0)));
	packedMaterial.a = 1.0;

	packedData.r = packNormal(getNormal(baseUV));
	packedData.g = packNormal(tbnMatrix[2]);
	packedData.b = 1.0;
	packedData.a = uintBitsToFloat(packUnorm2x16(lmUV));
}
