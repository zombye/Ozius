#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#define TEXTURE_RESOLUTION 16 // [16 32 64 128 256 512 1024 2048]

#define PSS_QUALITY 2 // 0 = Off. 1 = Low. 2 = Medium. 3 = High. [0 1 2 3]

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:01 */

layout (location = 0) out vec4 packedMaterial;
layout (location = 1) out vec4 data1;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec3 vsp;
in mat3 tbnMatrix;
in vec4 tint;
in vec2 texCoord;
in vec2 lmCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform vec3 shadowLightPosition;

uniform sampler2D albedo;
uniform sampler2D normals;
uniform sampler2D specular;

//--// Functions //--------------------------------------------------------------------------------------//

vec3 calculateParallaxCoord(vec2 coord, vec3 dir) {
	vec2 atlasTiles = textureSize(albedo, 0) / TEXTURE_RESOLUTION;
	vec4 tcoord = vec4(fract(coord * atlasTiles), floor(coord * atlasTiles));

	vec3 increment = vec3(0.25, -0.25, 1.0) * (dir / abs(dir.z)) * 0.0625;
	float foundHeight = textureLod(normals, coord, 0).a;
	vec3 offset = vec3(0.0, 0.0, 1.0);

	for (int i = 0; i < 32 && foundHeight < offset.z; i++) {
		offset += mix(vec3(0.0), increment, pow(offset.z - foundHeight, 0.8));
		foundHeight = textureLod(normals, (fract(tcoord.xy + offset.xy) + tcoord.zw) / atlasTiles, 0).a;
	}

	return vec3((fract(tcoord.xy + offset.xy) + tcoord.zw) / atlasTiles, offset.z);
}

float calculateParallaxSelfShadow(vec3 coord, vec3 dir) {
	#if PSS_QUALITY > 0
	if (dot(tbnMatrix[2], shadowLightPosition) <= 0.0) return 0.0;

	#if PSS_QUALITY == 1
	const int steps = 16;
	#elif PSS_QUALITY == 2
	const int steps = 32;
	#elif PSS_QUALITY == 3
	const int steps = 64;
	#endif
	const vec2 atlasTiles = textureSize(albedo, 0) / TEXTURE_RESOLUTION;

	vec4 tcoord = vec4(fract(coord.xy * atlasTiles), floor(coord.xy * atlasTiles));

	vec3 increment = vec3(0.25, -0.25, 1.0) * (dir / dir.z) * (1.0 / steps);
	vec3 offset = vec3(0.0, 0.0, coord.z);

	for (int i = 0; i < steps && offset.z < 1.0; i++) {
		offset += increment;

		float foundHeight = textureLod(normals, (fract(tcoord.xy + offset.xy) + tcoord.zw) / atlasTiles, 0).a;
		if (offset.z < foundHeight) return 0.0;
	}
	#endif

	return 1.0;
}

vec3 getNormal(vec2 coord) {
	return tbnMatrix * normalize(texture(normals, coord).rgb * 2.0 - 1.0);
}

float packNormal(vec3 normal) {
	return uintBitsToFloat(packUnorm2x16(normal.xy * inversesqrt(normal.z * 8.0 + 8.0) + 0.5));
}

void main() {
	vec3 pCoord = calculateParallaxCoord(texCoord, normalize(vsp) * tbnMatrix);

	vec4 albedoTex = texture(albedo, pCoord.st) * tint;
	if (albedoTex.a < 0.102) discard; // ~ 26 / 255

	vec4 specularTex = texture(specular, pCoord.st);

	float parallaxShadow = calculateParallaxSelfShadow(pCoord, normalize(shadowLightPosition * tbnMatrix));

	packedMaterial.r = uintBitsToFloat(packUnorm4x8(vec4(albedoTex.rgb, parallaxShadow)));
	packedMaterial.g = uintBitsToFloat(packUnorm4x8(specularTex));
	packedMaterial.b = uintBitsToFloat(packUnorm4x8(vec4(0.0, 0.0, 0.0, 1.0)));
	packedMaterial.a = albedoTex.a;

	data1.r = packNormal(getNormal(pCoord.st));
	data1.g = packNormal(tbnMatrix[2]);
	data1.b = 1.0;
	data1.a = uintBitsToFloat(packUnorm2x16(lmCoord));
}
