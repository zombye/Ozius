#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

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

uniform sampler2D noisetex;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"

#include "/lib/util/packing/normal.glsl"

vec2 pcb(vec2 coord, sampler2D sampler) {
	ivec2 res = textureSize(sampler, 0);
	coord *= res;

	vec2 fr = fract(coord);
	coord = floor(coord) + (fr * fr * (3.0 - 2.0 * fr)) + 0.5;

	return coord / res;
}
float calculateWaterWaves(vec2 pos) {
	float fbm = 0.0;
	float scale = 1.0;

	pos += frameTimeCounter;
	pos /= 128.0;

	const uint oct  = 5;
	const vec2 offs = vec2(1.512);
	const mat2 rot  = mat2(cos(2), sin(2), -sin(2), cos(2));
	for (uint i = 0; i < oct; i++) {
		fbm -= scale * texture(noisetex, pcb(frameTimeCounter * 0.01 + pos, noisetex)).r;
		pos = rot * (pos + offs / oct) * 2.0;
		scale *= 0.4;
	}

	return fbm * 0.1;
}
vec3 calculateWaterParallax(vec3 pos, vec3 dir) {
	const int steps = 16;

	vec3  increm = vec3(2.0 / steps) * (dir / abs(dir.z));
	vec3  offset = vec3(0.0, 0.0, 0.0);
	float height = calculateWaterWaves(pos.xy);

	for (int i = 0; i < steps && height < offset.z; i++) {
		offset += mix(vec3(0.0), increm, pow(offset.z - height, 0.8));
		height  = calculateWaterWaves(pos.xy + offset.xy);
	}

	return pos + vec3(offset.xy, 0.0);
}
vec3 calculateWaterNormal(vec3 pos, vec3 viewDir) {
	pos = calculateWaterParallax(pos.xzy, viewDir);

	vec3 p0 = pos + vec3(-0.1,-0.1, 0.0); p0.z += calculateWaterWaves(p0.xy);
	vec3 p1 = pos + vec3( 0.1,-0.1, 0.0); p1.z += calculateWaterWaves(p1.xy);
	vec3 p2 = pos + vec3(-0.1, 0.1, 0.0); p2.z += calculateWaterWaves(p2.xy);

	return normalize(tbnMatrix * cross(p1 - p0, p2 - p0));
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
