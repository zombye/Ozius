#version 420

//--// Configuration //----------------------------------------------------------------------------------//
/*
const float sunPathRotation = -40.0;

//--// Shadows

const int   shadowMapResolution = 2048; // [1024 2048 4096]
const float shadowDistance      = 16.0;

//--// Texture formats

const int colortex0Format = RGBA32F; // Material
const int colortex1Format = RGBA32F; // Normals, lightmap
const int colortex2Format = RGBA32F; // Transparent surfaces

const int colortex6Format = RGBA32F;
const int colortex7Format = RGBA32F; // Sky

const bool shadowHardwareFiltering0 = true;
const bool shadowHardwareFiltering1 = true;
*/
//--// Structs //----------------------------------------------------------------------------------------//

struct materialStruct {
	vec3  albedo;    // RGB of base texture.
	float specular;  // Specular R channel. In SEUS v11.0: Specularity
	float metallic;  // Specular G channel. In SEUS v11.0: Additive rain specularity
	float roughness; // Specular B channel. In SEUS v11.0: Roughness / Glossiness
	float clearcoat; // Specular A channel. In SEUS v11.0: Unused
	float dR;
	float dG;
	float dB;
	float dA;
};

struct surfaceStruct {
	materialStruct material;

	vec3 normal;
	vec3 normalGeom;

	vec4 depth; // x = depth0, y = depth1 (depth0 without transparent objects). zw = linearized xy

	mat2x3 positionScreen; // Position in screen-space
	mat2x3 positionView;   // Position in view-space
	mat2x3 positionLocal;  // Position in local-space
};

struct engineLightStruct {
	vec2 raw;
	vec3 block;
	vec3 sky;
};
struct lightStruct {
	engineLightStruct engine;

	float pss;
	float shadow;
};

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:67 */

layout (location = 0) out vec3 composite;
layout (location = 1) out vec3 sky;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform float shadowAngle;

uniform vec3 shadowLightPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform mat4 shadowProjection, shadowModelView;

uniform sampler2D colortex0, colortex1;

uniform sampler2D depthtex0, depthtex1;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"

#include "/lib/util/packing/normal.glsl"

//--//

#include "/lib/composite/get/material.fsh"
#include "/lib/composite/get/normal.fsh"

//--//

float linearizeDepth(float depth) {
	return 1.0 / ((depth * 2.0 - 1.0) * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}
vec3 screenSpaceToViewSpace(vec3 screenSpace) {
	vec4 viewSpace = gbufferProjectionInverse * vec4(screenSpace * 2.0 - 1.0, 1.0);
	return viewSpace.xyz / viewSpace.w;
}
vec3 viewSpaceToLocalSpace(vec3 viewSpace) {
	return (gbufferModelViewInverse * vec4(viewSpace, 1.0)).xyz;
}

//--//

#include "/lib/projection.glsl"

float miePhase(float cosTheta) {
	const float g  = 0.75;
	const float g2 = g * g;

	float p1 = (3.0 * (1.0 - g2)) / (2.0 * (2.0 + g2));
	float p2 = ((cosTheta * cosTheta) + 1.0) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);

	return p1 * p2;
}
float rayleighPhase(float cosTheta) {
	return 0.75 * ((cosTheta * cosTheta) + 1.0);
}

float atmosphereRelAM(float VoU) {
	float relAM = pow(1.0 - VoU, 4);
	return mix(1.0, 8.0, relAM);
}

vec3 skyAtmosphere(vec3 viewVec, vec3 sunVec) {
	float VoL = dot(viewVec, sunVec);
	float VoU = dot(viewVec, vec3(0.0, 0.0, 1.0));

	float mie      = 0.03 * miePhase(VoL);
	vec3  rayleigh = vec3(0.15, 0.5, 1.0) * rayleighPhase(VoL);
	return (rayleigh + mie) * atmosphereRelAM(VoU) * 0.5;
}

vec3 calculateSky(vec2 coord) {
	vec3 dir = equirectangleReverse(coord);

	vec3 sky = skyAtmosphere(dir, normalize(mat3(gbufferModelViewInverse) * shadowLightPosition).xzy);

	return sky;
}

//--//

engineLightStruct getEngineLight(vec2 coord) {
	engineLightStruct engine;

	engine.raw   = unpackUnorm2x16(floatBitsToUint(textureRaw(colortex1, fragCoord).a));
	engine.block = vec3(1.00, 0.50, 0.20) * 16.0 * (engine.raw.x / pow(16 * (1.0625 - engine.raw.x), 2.0));
	engine.sky   = vec3(1.00, 0.95, 0.90) * pow(engine.raw.y, 3.0);

	return engine;
}

float calculateShadows(vec3 positionLocal, vec3 normal) {
	vec3 shadowCoord = (shadowProjection * shadowModelView * vec4(positionLocal, 1.0)).xyz;

	float distortCoeff = 1.0 + length(shadowCoord.xy);

	float zBias = ((2.0 / shadowProjection[0].x) / textureSize(shadowtex0, 0).x) * shadowProjection[2].z;
	zBias *= tan(acos(abs(dot(normalize(shadowLightPosition), normal))));
	zBias *= distortCoeff * distortCoeff;
	zBias *= mix(1.0, SQRT2, abs(shadowAngle - 0.25) * 4.0);
	zBias -= 0.0001 * mix(1.0, SQRT2, abs(shadowAngle - 0.25) * 4.0);

	shadowCoord.z += zBias;

	shadowCoord.xy /= distortCoeff;
	shadowCoord.z *= 0.25;

	shadowCoord = shadowCoord * 0.5 + 0.5;

	float shadow = texture(shadowtex1, shadowCoord);

	return shadow * shadow;
}

//--//

void main() {
	sky = calculateSky(fragCoord);

	surfaceStruct surface;
	lightStruct   light;

	surface.material = getMaterial(fragCoord, light.pss);

	surface.normal     = getNormal(fragCoord);
	surface.normalGeom = getNormalGeom(fragCoord);

	surface.depth.x = texture(depthtex0, fragCoord).r;
	surface.depth.y = texture(depthtex1, fragCoord).r;
	surface.depth.z = linearizeDepth(surface.depth.x);
	surface.depth.w = linearizeDepth(surface.depth.y);

	surface.positionScreen[0] = vec3(fragCoord, surface.depth.x);
	surface.positionScreen[1] = vec3(fragCoord, surface.depth.y);
	surface.positionView[0]   = screenSpaceToViewSpace(surface.positionScreen[0]);
	surface.positionView[1]   = screenSpaceToViewSpace(surface.positionScreen[1]);
	surface.positionLocal[0]  = viewSpaceToLocalSpace(surface.positionView[0]);
	surface.positionLocal[1]  = viewSpaceToLocalSpace(surface.positionView[1]);

	light.engine = getEngineLight(fragCoord);
	light.shadow = calculateShadows(surface.positionLocal[1], surface.normalGeom);

	composite = mix(surface.material.albedo, vec3(0.0), surface.material.metallic) * (light.engine.block + light.engine.sky + (light.shadow * light.pss));
}
