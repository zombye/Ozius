#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

//--// Misc

const float sunPathRotation = -40.0;
const int noiseTextureResolution = 64;

//--// Shadows

const int   shadowMapResolution = 2048; // [1024 2048 4096]
const float shadowDistance      = 16.0; // [16.0 32.0]

//--// Texture formats
/*
const int colortex0Format = RGBA32F; // Material
const int colortex1Format = RGBA32F; // Normals, lightmap
const int colortex2Format = RGBA32F; // Transparent surfaces
const int colortex3Format = RGBA32F; // Water data

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

uniform sampler2D depthtex1;

uniform sampler2DShadow shadowtex0;

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

#include "/lib/light/engine.fsh"
#include "/lib/light/shadow.fsh"

//--//

void main() {
	sky = calculateSky(fragCoord);

	surfaceStruct surface;

	surface.depth.y = texture(depthtex1, fragCoord).r;

	if (surface.depth.y == 1.0) return;

	surface.positionScreen[1] = vec3(fragCoord, surface.depth.y);
	surface.positionView[1]   = screenSpaceToViewSpace(surface.positionScreen[1]);
	surface.positionLocal[1]  = viewSpaceToLocalSpace(surface.positionView[1]);

	surface.depth.w = surface.positionView[1].z;

	lightStruct light;

	surface.material = getMaterial(fragCoord, light.pss);

	surface.normal     = getNormal(fragCoord);
	surface.normalGeom = getNormalGeom(fragCoord);

	//--//

	light.engine = calculateEngineLight(unpackUnorm2x16(floatBitsToUint(textureRaw(colortex1, fragCoord).a)));

	if (light.pss > 0.0) {
		light.shadow = calculateShadow(surface.positionLocal[1], surface.normalGeom);
	} else {
		light.shadow = 0.0;
	}

	composite = mix(surface.material.albedo, vec3(0.0), surface.material.metallic) * (light.engine.block + light.engine.sky + (light.shadow * light.pss));
}
