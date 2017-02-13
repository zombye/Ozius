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
in vec2 baseUV, lmUV;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform vec3 shadowLightPosition;

uniform sampler2D base, specular;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/util/packing/normal.glsl"

void main() {
	vec4 baseTex = texture(base, baseUV) * tint;
	if (baseTex.a < 0.102) discard; // ~ 26 / 255

	vec4 diff = vec4(baseTex.rgb, 1.0);
	vec4 spec = texture(specular, baseUV);

	//--//

	packedMaterial.r = uintBitsToFloat(packUnorm4x8(diff));
	packedMaterial.g = uintBitsToFloat(packUnorm4x8(spec));
	packedMaterial.b = uintBitsToFloat(packUnorm4x8(vec4(0.0, 0.0, 0.0, 1.0)));
	packedMaterial.a = 1.0;

	packedData.rg = vec2(packNormal(tbnMatrix[2]));
	packedData.b = 1.0;
	packedData.a = uintBitsToFloat(packUnorm2x16(lmUV));
}
