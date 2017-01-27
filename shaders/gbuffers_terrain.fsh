#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

#define PM_QUALITY 2 // 0 = Off. 1 = Low. 2 = Medium. 3 = High. [0 1 2 3]
#define PM_DEPTH 0.25
//#define PM_DEPTH_WRITE

#define PSS_QUALITY 2 // 0 = Off. 1 = Low. 2 = Medium. 3 = High. [0 1 2 3]

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:01 */

layout (location = 0) out vec4 packedMaterial;
layout (location = 1) out vec4 packedData;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec3 positionView;

in mat3 tbnMatrix;
in vec4 tint;
in vec2 baseUV, lmUV;

in float isMetal;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform vec3 shadowLightPosition;

uniform mat4 gbufferProjection;

uniform sampler2D base, specular;
uniform sampler2D normals;

//--// Functions //--------------------------------------------------------------------------------------//

float delinearizeDepth(float depth) {
	return ((depth * gbufferProjection[2].z + gbufferProjection[3].z) / (depth * gbufferProjection[2].w + gbufferProjection[3].w)) * 0.5 + 0.5;
}

vec3 calculateParallaxCoord(vec2 coord, vec3 dir) {
	#if PM_QUALITY > 0
	vec2 atlasTiles = textureSize(base, 0) / TEXTURE_RESOLUTION;
	vec4 tcoord = vec4(fract(coord * atlasTiles), floor(coord * atlasTiles));

	#if PM_QUALITY == 1
	const int steps = 16;
	#elif PM_QUALITY == 2
	const int steps = 32;
	#elif PM_QUALITY == 3
	const int steps = 64;
	#endif

	vec3 increment = 2.0 * vec3(PM_DEPTH, PM_DEPTH, 1.0) * (dir / abs(dir.z)) / steps;
	float foundHeight = textureLod(normals, coord, 0).a;
	vec3 offset = vec3(0.0, 0.0, 1.0);

	for (int i = 0; i < steps && foundHeight < offset.z; i++) {
		offset += mix(vec3(0.0), increment, pow(offset.z - foundHeight, 0.8));
		foundHeight = textureLod(normals, (fract(tcoord.xy + offset.xy) + tcoord.zw) / atlasTiles, 0).a;
	}

	#ifdef PM_DEPTH_WRITE
	gl_FragDepth = delinearizeDepth(positionView.z + (normalize(positionView).z * length(vec3(offset.xy, offset.z * PM_DEPTH - PM_DEPTH))));
	#endif

	return vec3((fract(tcoord.xy + offset.xy) + tcoord.zw) / atlasTiles, offset.z);
	#else
	return vec3(coord, 1.0);
	#endif
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
	const vec2 atlasTiles = textureSize(base, 0) / TEXTURE_RESOLUTION;

	vec4 tcoord = vec4(fract(coord.xy * atlasTiles), floor(coord.xy * atlasTiles));

	vec3 increment = vec3(PM_DEPTH, PM_DEPTH, 1.0) * (dir / dir.z) / steps;
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
	vec3 tsn = texture(normals, coord).rgb;
	tsn.xy += 0.5 / 255.0; // Need to add this for correct results.
	return tbnMatrix * normalize(tsn * 2.0 - 1.0);
}

#include "/lib/util/packing/normal.glsl"

void main() {
	vec3 pCoord = calculateParallaxCoord(baseUV, normalize(positionView) * tbnMatrix);

	vec4 baseTex = texture(base, pCoord.st) * tint;
	if (baseTex.a < 0.102) discard; // ~ 26 / 255
	vec4 specTex = texture(specular, pCoord.st);

	vec4 diff = vec4(mix(baseTex.rgb, vec3(0.0), isMetal), 1.0);
	vec4 spec = vec4(mix(specTex.rrr, baseTex.rgb, isMetal), specTex.b);

	//--//

	packedMaterial.r = uintBitsToFloat(packUnorm4x8(diff));
	packedMaterial.g = uintBitsToFloat(packUnorm4x8(spec));
	packedMaterial.b = uintBitsToFloat(packUnorm4x8(vec4(0.0, 0.0, 0.0, 1.0)));
	packedMaterial.a = 1.0;

	packedData.r = packNormal(getNormal(pCoord.st));
	packedData.g = packNormal(tbnMatrix[2]);
	packedData.b = calculateParallaxSelfShadow(pCoord, normalize(shadowLightPosition * tbnMatrix));;
	packedData.a = uintBitsToFloat(packUnorm2x16(lmUV));
}
