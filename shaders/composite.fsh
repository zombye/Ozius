#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

#define COMPOSITE 0

#include "/cfg/globalIllumination.scfg"

//--// Misc

const float sunPathRotation = -40.0;
const int noiseTextureResolution = 64;

//--// Shadows

const int   shadowMapResolution = 2048; // [1024 2048 4096]
const float shadowDistance      = 16.0; // [16.0 32.0]

//--// Texture formats
/*
const int colortex0Format = RG32F;   // Material
const int colortex1Format = RGB32F;  // Normals, lightmap
const int colortex2Format = RGBA32F; // Transparent surfaces
const int colortex3Format = RGBA32F; // Water data
const int colortex4Format = RGBA32F;
const int colortex5Format = RGBA32F;

const int colortex7Format = RGB32F; // Sky
*/

const bool shadowHardwareFiltering1 = true;

const bool shadowtex0Mipmap   = true;
const bool shadowtex1Mipmap   = false;
const bool shadowcolor0Mipmap = true;
const bool shadowcolor1Mipmap = true;

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:4 */

layout (location = 0) out vec3 gi;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex1;

uniform mat4 shadowProjection, shadowModelView;
uniform mat4 shadowProjectionInverse;

uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"
#include "/lib/illuminance.glsl"

#include "/lib/util/maxof.glsl"
#include "/lib/util/noise.glsl"

//--//

vec3 screenSpaceToViewSpace(vec3 screenSpace) {
	vec4 viewSpace = gbufferProjectionInverse * vec4(screenSpace * 2.0 - 1.0, 1.0);
	return viewSpace.xyz / viewSpace.w;
}
vec3 viewSpaceToLocalSpace(vec3 viewSpace) {
	return (gbufferModelViewInverse * vec4(viewSpace, 1.0)).xyz;
}
vec3 projectShadowSpace(vec3 pos) {
	pos = (shadowProjection * vec4(pos, 1.0)).xyz;
	return pos / vec3(vec2(1.0 + length(pos.xy)), 4.0);
}
vec2 projectShadowSpace(vec2 pos) {
	pos = mat2(shadowProjection) * pos;
	return pos / (1.0 + length(pos));
}

#include "/lib/util/packing/normal.glsl"
#include "/lib/composite/get/normal.fsh"

vec3 calculateGI(vec3 positionLocal, vec3 normal, bool translucent) {
	const float stp = 0.5 * (GI_RADIUS / (sqrt(GI_SAMPLES) - 1.0));
	vec2 noise = noise2(fragCoord) * stp - (0.5 * stp); // 4x slower for same sample count, but looks 10x better. difference decreases as sample count increases

	vec3 shadowPos    = (shadowModelView * vec4(positionLocal, 1.0)).xyz;
	vec3 shadowNormal = mat3(shadowModelView) * mat3(gbufferModelViewInverse) * normal;

	vec3 result = vec3(0.0);

	for (float x = -GI_RADIUS; x < GI_RADIUS; x += stp) {
		for (float y = -GI_RADIUS; y <= GI_RADIUS; y += stp) {
			vec2 offset = vec2(x, y) + noise;

			if (dot(shadowNormal.xy, offset) <= 0.0 || dot(offset, offset) > GI_RADIUS * GI_RADIUS) continue;

			vec3 samplePos   = vec3(shadowPos.xy + offset, 0.0);
			vec2 sampleCoord = projectShadowSpace(samplePos.xy) * 0.5 + 0.5;
			samplePos.z = (textureLod(shadowtex0, sampleCoord, 2).r * 8.0 - 4.0) * shadowProjectionInverse[2].z + shadowProjectionInverse[3].z;

			vec3 diffp = samplePos - shadowPos;
			float diffd2 = dot(diffp, diffp);

			float dm = 1.0 / (diffd2 + 1.0);
			if (dm <= 1.0 / (GI_RADIUS * GI_RADIUS + 1.0)) continue;

			vec3 sampleNormal = textureLod(shadowcolor1, sampleCoord, 2).rgb * -2.0 + 1.0;
			vec3 ams = max(vec3(inversesqrt(diffd2) * diffp * mat2x3(shadowNormal, sampleNormal), -sampleNormal.z), 0.0);
			float am = mix(ams.x * ams.y, 1.0, translucent) * ams.z;
			if (am <= 0.0) continue;

			result += textureLod(shadowcolor0, sampleCoord, 5).rgb * am * dm;
		}
	}
	result /= PI;

	return result / (GI_SAMPLES / GI_RADIUS);
}

//--//

void main() {
	#ifdef GI
	vec2 gifc = fragCoord * (1.0 / GI_RESOLUTION);
	if (all(lessThan(gifc, vec2(1.0)))) {
		int id = int(unpackUnorm4x8(floatBitsToUint(texelFetch(colortex0, ivec2(gifc * textureSize(colortex0, 0)), 0).r)).a * 255.0);

		bool translucent =
		   id == 18
		|| id == 30
		|| id == 31
		|| id == 37
		|| id == 38
		|| id == 59
		|| id == 83
		|| id == 106
		|| id == 111
		|| id == 141
		|| id == 142
		|| id == 161
		|| id == 175
		|| id == 207;

		gi = calculateGI(viewSpaceToLocalSpace(screenSpaceToViewSpace(vec3(gifc, texture(depthtex1, gifc).r))), getNormal(gifc), translucent);
	}
	else
	#endif
	gi = vec3(0.0);
}
