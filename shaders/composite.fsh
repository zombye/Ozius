#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

#define RAYTRACE_SAMPLES 1 // [1 2 4 8 16]
#define RAYTRACE_BOUNCES 2 // [1 2 4]

//--// Misc

const float sunPathRotation = -40.0;

//--// Texture formats
/*
const int colortex0Format = RGBA32F; // Material
const int colortex1Format = RGBA32F; // Normals, lightmap
const int colortex2Format = RGBA32F; // Transparent surfaces
const int colortex3Format = RGBA32F; // Current frame
const int colortex4Format = RGBA32F; // Previous frame
*/

const bool colortex4Clear = false;

//--// Structs //----------------------------------------------------------------------------------------//

struct materialStruct {
	vec3 diffuse;  // RGB of base texture.
	vec3 specular; // RGB of specular texture.
	vec3 emission; // Currently not controlled by a texture and is same color as diffuse.
	
	float roughness; // B of normal texture.
};
const materialStruct emptyMaterial = materialStruct(vec3(0.0), vec3(0.0), vec3(0.0), 0.0);

struct surfaceStruct {
	materialStruct material;

	vec3 normal;
	vec3 normalGeom;

	vec2 depth; // y is linearized

	vec3 positionScreen; // Position in screen-space
	vec3 positionView;   // Position in view-space
	vec3 positionLocal;  // Position in local-space
};

struct lightStruct {
	vec2 engine;
	float pss;

	vec3 global;
	vec3 sky;
	vec3 block;
};

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:34 */

layout (location = 0) out vec3 composite;
layout (location = 1) out vec3 prevComposite;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform int frameCounter;

uniform float viewWidth, viewHeight;

//--//

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferProjection, gbufferModelView;
uniform mat4 gbufferPreviousProjection, gbufferPreviousModelView;
uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;

//--//

uniform sampler2D colortex0, colortex1;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"

#include "/lib/util/packing/normal.glsl"

#include "/lib/util/hammersley.glsl"
#include "/lib/util/noise.glsl"

//--//

#include "/lib/composite/get/material.fsh"
#include "/lib/composite/get/normal.fsh"

//--//

float linearizeDepth(float depth) {
	return -1.0 / ((depth * 2.0 - 1.0) * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}
vec3 screenSpaceToViewSpace(vec3 screenSpace) {
	vec4 viewSpace = gbufferProjectionInverse * vec4(screenSpace * 2.0 - 1.0, 1.0);
	return viewSpace.xyz / viewSpace.w;
}
vec3 viewSpaceToLocalSpace(vec3 viewSpace) {
	return (gbufferModelViewInverse * vec4(viewSpace, 1.0)).xyz;
}
vec3 viewSpaceToScreenSpace(vec3 viewSpace) {
	vec4 screenSpace = gbufferProjection * vec4(viewSpace, 1.0);
	return (screenSpace.xyz / screenSpace.w) * 0.5 + 0.5;
}

//--//

vec3 f0ToIOR(vec3 f0) {
	f0 = sqrt(f0);
	return (1.0 + f0) / (1.0 - f0);
}

vec3 fresnel(float cosTheta, vec3 f0) {
	float n1 = 1.0;
	vec3 n2 = f0ToIOR(f0);

	float sinTheta = sin(acos(cosTheta));
	vec3 p = ((n1 / n2) * sinTheta); p = sqrt(1.0 - (p * p));

	vec3 rs = ((n1 * cosTheta) - (n2 * p)) / ((n1 * cosTheta) + (n2 * p)); rs *= rs;
	vec3 rp = ((n1 * p) - (n2 * cosTheta)) / ((n1 * p) + (n2 * cosTheta)); rp *= rp;
	return 0.5 * (rs + rp);
}

vec3 getTemporalNoiseVector(vec2 coord, uint curSample, uint curBounce) {
	coord += hammersley((frameCounter % 100) * RAYTRACE_SAMPLES + curSample, 100 * RAYTRACE_SAMPLES);
	coord += vec2(1,-1) * curBounce;

	vec4 nv = noise4(coord);

	return normalize(nv.xyz * 2.0 - 1.0) * (nv.w * 0.5 + 0.5);
}
bool isSpecularBounce(vec2 coord, uint curSample, uint curBounce, vec3 reflectance) {
	coord += hammersley((frameCounter % 100) * RAYTRACE_SAMPLES + curSample, 100 * RAYTRACE_SAMPLES);
	coord += vec2(1,-1) * curBounce;

	if (all(greaterThan(vec3(noise1(coord)), reflectance))) return false;

	return true;
}

//--//

#include "/lib/composite/raytracer.fsh"

vec3 raytrace(surfaceStruct surface) {
	vec3 result = surface.material.emission;

	for (uint i = 0; i < RAYTRACE_SAMPLES; i++) {
		materialStruct hitMaterial = surface.material;

		vec3 reflColor = vec3(1.0);
		vec3 hitCoord  = surface.positionScreen;
		vec3 hitPos    = surface.positionView;
		vec3 hitNormal = surface.normal;
		vec3 vector    = normalize(-surface.positionView);

		for (uint j = 0; j < RAYTRACE_BOUNCES; j++) {
			bool specularBounce = isSpecularBounce(fragCoord, i, j, fresnel(dot(vector, hitNormal), surface.material.specular));
			reflColor *= mix(hitMaterial.diffuse, hitMaterial.specular, specularBounce);

			vec3 reflectionVector = reflect(vector, hitNormal);

			vector = mix(getTemporalNoiseVector(fragCoord, i, j), reflectionVector, specularBounce);
			vector *= sign(dot(vector, hitNormal));

			if (raytraceIntersection(hitPos, vector, hitCoord, hitPos)) {
				hitMaterial = getMaterial(hitCoord.st);
				hitNormal   = getNormal(hitCoord.st);
			} else {
				break;
			}

			result += reflColor * hitMaterial.emission;
		}
	}
	result /= RAYTRACE_SAMPLES;

	return result;
}

//--//

vec3 getPreviousFrame(vec3 positionLocal) {
	mat4 previousMVP = gbufferPreviousProjection * gbufferPreviousModelView;
	vec4 previousSSP = previousMVP * vec4((positionLocal + cameraPosition) - previousCameraPosition, 1.0); previousSSP /= previousSSP.w;

	return texture(colortex4, previousSSP.xy * 0.5 + 0.5).rgb;
}

//--//

void main() {
	surfaceStruct surface;

	surface.depth.x = texture(depthtex1, fragCoord).r;
	if (surface.depth.x == 1.0) return;

	surface.positionScreen = vec3(fragCoord, surface.depth.x);
	surface.positionView   = screenSpaceToViewSpace(surface.positionScreen);
	surface.positionLocal  = viewSpaceToLocalSpace(surface.positionView);

	surface.depth.y = surface.positionView.z;

	surface.material = getMaterial(fragCoord);

	surface.normal     = getNormal(fragCoord);
	surface.normalGeom = getNormalGeom(fragCoord);

	vec3 currFrame = raytrace(surface);
	vec3 prevFrame = getPreviousFrame(surface.positionLocal);
	
	composite = mix(currFrame, prevFrame, 0.95);
	prevComposite = composite;
}
