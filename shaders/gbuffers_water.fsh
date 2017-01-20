#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

//--// Structs //----------------------------------------------------------------------------------------//

struct surfaceStruct {
	vec3 normal;
	vec3 normalGeom;

	vec2 depth; // y is linearized

	vec3 positionScreen; // Position in screen-space
	vec3 positionView;   // Position in view-space
	vec3 positionLocal;  // Position in local-space
};

struct lightStruct {
	vec2 engine;

	vec3 global;
	vec3 sky;
	vec3 block;
};

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:23 */

layout (location = 0) out vec4 data0;
layout (location = 1) out vec4 data1;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec3 positionView, positionLocal;

in mat3 tbnMatrix;
in vec4 tint;
in vec2 baseUV, lmUV;

in float blockID;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform float shadowAngle;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

uniform mat4 shadowModelView, shadowProjection;

uniform sampler2D base;
uniform sampler2D normals;

uniform sampler2DShadow shadowtex0;

uniform sampler2D noisetex;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"
#include "/lib/illuminance.glsl"
#include "/lib/time.glsl"

#include "/lib/util/packing/normal.glsl"

#include "/lib/util/textureSmooth.glsl"

//--//

vec3 getNormal(vec2 coord) {
	vec3 tsn = texture(normals, coord).rgb;
	tsn.xy += 0.5 / 255.0; // Need to add this for correct results.
	return tbnMatrix * normalize(tsn * 2.0 - 1.0);
}

//--//

float calculateWaterWaves(vec2 pos) {
	float fbm = 0.0;
	float scale = 1.0;

	pos += globalTime;
	pos /= 128.0;

	for (uint i = 0; i < 5; i++) {
		fbm -= scale * textureSmooth(noisetex, globalTime * 0.01 + pos).r;
		pos = mat2(cos(2), sin(2), -sin(2), cos(2)) * (pos + 0.3024) * 2.0;
		scale *= 0.4;
	}

	return fbm * 0.1;
}
vec3 calculateWaterParallax(vec3 pos, vec3 dir) {
	const int steps = 8;

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

//--//

#include "/lib/light/global.fsh"
#include "/lib/light/sky.fsh"
#include "/lib/light/block.fsh"

//--//

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

	surfaceStruct surface;
	surface.positionLocal = positionLocal;

	surface.normal     = getNormal(baseUV);
	surface.normalGeom = tbnMatrix[2];

	lightStruct light;
	light.engine = lmUV;

	light.global = calculateGlobalLight(surface);
	light.sky    = calculateSkyLight(light.engine.y);
	light.block  = calculateBlockLight(light.engine.x);

	data0.rgb *= light.global + light.sky;
}
