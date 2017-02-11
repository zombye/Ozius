#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

#define COMPOSITE

#include "/cfg/hssrs.scfg"

#define REFLECTION_SAMPLES 1 // [0 1 2 4 8 16]

//--// Structs //----------------------------------------------------------------------------------------//

struct materialStruct {
	vec3 diffuse;  // RGB of base texture
	vec3 specular; // Currently R of specular texture

	float roughness; // Currently B of specular texture
};

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

struct worldStruct {
	vec3 globalLightVector;
	vec3 globalLightColor;
};

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:5 */

layout (location = 0) out vec3 composite;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

in worldStruct world;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform float shadowAngle;

uniform vec3 skyColor;

uniform vec3 shadowLightPosition;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 shadowProjection, shadowModelView;

uniform sampler2D colortex0, colortex1;
uniform sampler2D depthtex1;

uniform sampler2DShadow shadowtex1;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"
#include "/lib/illuminance.glsl"
#include "/lib/time.glsl"

#include "/lib/util/packing/normal.glsl"
#include "/lib/util/noise.glsl"
#include "/lib/util/sumof.glsl"

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
vec3 viewSpaceToScreenSpace(vec3 viewSpace) {
	vec4 screenSpace = gbufferProjection * vec4(viewSpace, 1.0);
	return (screenSpace.xyz / screenSpace.w) * 0.5 + 0.5;
}
vec3 viewSpaceToLocalSpace(vec3 viewSpace) {
	return (gbufferModelViewInverse * vec4(viewSpace, 1.0)).xyz;
}

//--//

#include "/lib/light/global.fsh"
#include "/lib/light/sky.fsh"
#include "/lib/light/block.fsh"

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

	//--//

	lightStruct light;

	light.pss = texture(colortex1, fragCoord).b;
	light.engine = unpackUnorm2x16(floatBitsToUint(textureRaw(colortex1, fragCoord).a));

	if (light.pss > 0) {
		light.global = calculateGlobalLight(world, surface);
	} else {
		light.global = vec3(0.0);
	}

	light.sky   = calculateSkyLight(light.engine.y);
	light.block = calculateBlockLight(light.engine.x);

	composite = light.global + light.sky + light.block;
	#if REFLECTION_SAMPLES > 0
	composite *= surface.material.diffuse;
	#else
	composite *= mix(surface.material.diffuse, vec3(1.0), surface.material.specular);
	#endif
}
