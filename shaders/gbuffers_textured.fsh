#version 420

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:01 */

layout (location = 0) out vec4 packedMaterial;
layout (location = 1) out vec4 packedData;

//--// Inputs //-----------------------------------------------------------------------------------------//

in mat3 tbnMatrix;
in vec4 tint;
in vec2 baseUV, lmUV;
in float blockID;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform sampler2D base, specular;
uniform sampler2D normals;

//--// Functions //--------------------------------------------------------------------------------------//

vec3 getNormal(vec2 coord) {
	vec2 compNorm = texture(normals, coord, -2).rg;
	compNorm += 0.5 / 255.0; // Need to add this for correct results.

	vec3 tsn = vec3(compNorm, sqrt(1.0 - dot(compNorm, compNorm)));
	return tbnMatrix * normalize(tsn * 2.0 - 1.0);
}

#include "/lib/util/packing/normal.glsl"

void main() {
	vec4 diff = texture(base, baseUV, -2) * tint;
	if (diff.a < 0.102) discard; // ~ 26 / 255
	diff.a = texture(normals, baseUV, -2).b; // roughness
	vec4 spec = texture(specular, baseUV, -2);
	vec4 emis = vec4(diff.rgb * float(abs(blockID - 500) < 0.1), 0.0);

	//--//

	packedMaterial.r = uintBitsToFloat(packUnorm4x8(diff));
	packedMaterial.g = uintBitsToFloat(packUnorm4x8(spec));
	packedMaterial.b = uintBitsToFloat(packUnorm4x8(emis));
	packedMaterial.a = 1.0;

	packedData.r = packNormal(getNormal(baseUV));
	packedData.g = packNormal(tbnMatrix[2]);
	packedData.b = 1.0;
	packedData.a = uintBitsToFloat(packUnorm2x16(lmUV));
}
