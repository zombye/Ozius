#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

//--// Shadows

const int   shadowMapResolution = 2048; // [1024 2048 4096]
const float shadowDistance      = 16.0; // [16.0 32.0]

//--// Structs //----------------------------------------------------------------------------------------//

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

/* DRAWBUFFERS:23 */

layout (location = 0) out vec4 data0;
layout (location = 1) out vec4 data1;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec3 positionLocal;

in mat3 tbnMatrix;
in vec4 tint;
in vec2 baseUV, lmUV;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform float shadowAngle;

uniform vec3 shadowLightPosition;

uniform mat4 shadowModelView, shadowProjection;

uniform sampler2D base;

uniform sampler2DShadow shadowtex0;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"

#include "/lib/util/packing/normal.glsl"

#include "/lib/light/engine.fsh"
#include "/lib/light/shadow.fsh"

void main() {
	data0 = texture(base, baseUV) * tint;
	if (data0.a == 0.0) discard;

	data0.rgb = pow(data0.rgb, vec3(GAMMA));

	data1.r = packNormal(tbnMatrix[2]);
	data1.g = packNormal(tbnMatrix[0]);
	data1.b = lmUV.y;
	data1.a = 1.0;

	lightStruct light;
	light.engine = calculateEngineLight(lmUV);
	light.shadow = calculateShadow(positionLocal, tbnMatrix[2]);
	light.pss = 1.0;

	data0.rgb *= light.engine.block + light.engine.sky + (light.shadow * light.pss);
}
