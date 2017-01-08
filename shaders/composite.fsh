#version 400

//--// Configuration //----------------------------------------------------------------------------------//
/*
const int colortex0Format = RGBA16;
const int colortex1Format = RGBA16;
const int colortex2Format = RGBA32F;
const int colortex3Format = RGBA16; // Transparent surfaces

const int colortex6Format = RGBA32F;
const int colortex7Format = RGBA32F; // Sky
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

	vec4 depth; // x = depth0, y = depth1 (depth0 without transparent objects). zw = linearized xy

	mat2x3 positionScreen; // Position in screen-space
	mat2x3 positionView;   // Position in view-space
	mat2x3 positionLocal;  // Position in local-space
};

struct lightStruct {
	vec3 block;
	vec3 sky;
}light;

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:67 */

layout (location = 0) out vec3 composite;
layout (location = 1) out vec3 sky;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform vec3 shadowLightPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"

materialStruct getMaterial(vec2 coord) {
	materialStruct material;

	vec4 tex0 = texture(colortex0, coord);
	vec4 tex1 = texture(colortex1, coord);

	material.albedo    = tex0.rgb;
	material.specular  = tex1.r;
	material.metallic  = tex1.g;
	material.roughness = tex1.b;
	material.clearcoat = tex1.a;

	return material;
}
vec3 getNormal(vec2 coord) {
	vec4 normal = vec4(texture(colortex2, coord).rg * 2.0 - 1.0, 1.0, -1.0);
	normal.z    = dot(normal.xyz, -normal.xyw);
	normal.xy  *= sqrt(normal.z);
	return normal.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}

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

void main() {
	sky = calculateSky(fragCoord);

	surfaceStruct surface;

	surface.material = getMaterial(fragCoord);

	surface.normal = getNormal(fragCoord);

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

	vec2 lm = texture(colortex2, fragCoord).ba;
	light.block = vec3(1.00, 0.50, 0.20) * 16.0 * (lm.x / pow(16 * (1.0625 - lm.x), 2.0));
	light.sky   = vec3(1.00, 0.95, 0.90) * pow(lm.y, 3.0);

	composite = mix(surface.material.albedo, vec3(0.0), surface.material.metallic) * (light.block + light.sky);
}
