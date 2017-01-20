#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#define COMPOSITE

#include "/cfg/global.scfg"

//--// Structs //----------------------------------------------------------------------------------------//

struct materialStruct {
	vec3  albedo;    // RGB of base texture.
	float specular;  // Specular R channel. In SEUS v11.0: Specularity
	float metallic;  // Specular G channel. In SEUS v11.0: Additive rain specularity
	float roughness; // Specular B channel. In SEUS v11.0: Roughness / Glossiness
	float clearcoat; // Specular A channel. In SEUS v11.0: Unused
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

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:5 */

layout (location = 0) out vec3 composite;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform float shadowAngle;

uniform vec3 shadowLightPosition;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 shadowProjection, shadowModelView;

uniform sampler2D colortex0, colortex1;
uniform sampler2D depthtex1;

uniform sampler2DShadow shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"
#include "/lib/illuminance.glsl"
#include "/lib/time.glsl"

#include "/lib/util/packing/normal.glsl"
#include "/lib/util/sumof.glsl"

//--//

#include "/lib/composite/get/material.fsh"
#include "/lib/composite/get/normal.fsh"

//--//

vec3 screenSpaceToViewSpace(vec3 screenSpace) {
	vec4 viewSpace = gbufferProjectionInverse * vec4(screenSpace * 2.0 - 1.0, 1.0);
	return viewSpace.xyz / viewSpace.w;
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

	lightStruct light;

	surface.material = getMaterial(fragCoord, light.pss);

	surface.normal     = getNormal(fragCoord);
	surface.normalGeom = getNormalGeom(fragCoord);

	//--//

	light.engine = unpackUnorm2x16(floatBitsToUint(textureRaw(colortex1, fragCoord).a));

	if (light.pss > 0) {
		light.global = calculateGlobalLight(surface);
	} else {
		light.global = vec3(0.0);
	}

	light.sky   = calculateSkyLight(light.engine.y);
	light.block = calculateBlockLight(light.engine.x);

	composite = surface.material.albedo * (light.global + light.sky + light.block);
}
