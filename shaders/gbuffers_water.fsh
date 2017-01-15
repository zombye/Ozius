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

in vec3 positionView;
in vec3 positionLocal;

in mat3 tbnMatrix;
in vec4 tint;
in vec2 baseUV, lmUV;

in float blockID;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform float shadowAngle;
uniform float frameTimeCounter;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

uniform mat4 shadowModelView, shadowProjection;

uniform sampler2D base;

uniform sampler2DShadow shadowtex0;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"

#include "/lib/util/packing/normal.glsl"

float calculateWaterWaves(vec3 positionWorld) {
	// TODO
	return 0.0;
}
vec3 calculateWaterParallax(vec3 pos, vec3 dir) {
	vec3  increm = vec3(0.05) * (dir / abs(dir.z));
	vec3  offset = vec3(0.0, 0.0, 0.0);
	float height = calculateWaterWaves(pos);

	for (int i = 0; i < 32 && height < offset.z; i++) {
		offset += mix(vec3(0.0), increm, pow(offset.z - height, 0.8));
		height  = calculateWaterWaves(pos + vec3(offset.x, 0.0, offset.y));
	}

	return pos + vec3(offset.x, 0.0, offset.y);
}
vec3 calculateWaterNormal(vec3 positionWorld, vec3 viewDir) {
	positionWorld = calculateWaterParallax(positionWorld, viewDir);

	vec3 p1 = positionWorld - vec3(0.1, 0.0, 0.1);
	vec3 p2 = positionWorld + vec3(0.1, 0.0, 0.0);
	vec3 p3 = positionWorld + vec3(0.0, 0.0, 0.1);
	p1.y += calculateWaterWaves(p1);
	p2.y += calculateWaterWaves(p2);
	p3.y += calculateWaterWaves(p3);

	return tbnMatrix * normalize(cross(p3 - p1, p2 - p1).xzy);
}

#include "/lib/light/engine.fsh"
#include "/lib/light/shadow.fsh"

void main() {
	if (abs(blockID - 8.5) < 0.6) {
		vec3 viewDir = normalize(positionView) * tbnMatrix;
		data0 = vec4(0.0, 0.0, 0.0, 0.2);
		data1.r = packNormal(calculateWaterNormal(positionLocal + cameraPosition, viewDir));
		data1.g = 0.0;
		data1.b = lmUV.y;
		data1.a = 1.0;

		return;
	}

	data1 = vec4(0.0);

	data0 = texture(base, baseUV) * tint;
	if (data0.a == 0.0) discard;

	data0.rgb = pow(data0.rgb, vec3(GAMMA));

	lightStruct light;
	light.engine = calculateEngineLight(lmUV);
	light.shadow = calculateShadow(positionLocal, tbnMatrix[2]);
	light.pss = 1.0;

	data0.rgb *= light.engine.block + light.engine.sky + (light.shadow * light.pss);
}
