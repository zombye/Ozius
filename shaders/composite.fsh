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
const int colortex4Format = RGBA32F;
const int colortex5Format = RGBA32F;

const int colortex7Format = RGBA32F; // Sky
*/

const bool shadowHardwareFiltering1 = true;

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:7 */

layout (location = 0) out vec3 sky;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform float sunAngle;

uniform vec3 skyColor;

uniform vec3 shadowLightPosition;

uniform mat4 gbufferModelViewInverse;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"
#include "/lib/illuminance.glsl"

#include "/lib/util/maxof.glsl"

//--//

vec3 unprojectSky(vec2 p) {
	p  = p * 2.0 - 1.0;
	p *= maxof(abs(normalize(p)));

	vec4 u = vec4(p, 1.0, -1.0);
	u.z    = dot(u.xyz, -u.xyw);
	u.xy  *= sqrt(u.z);
	return u.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}

float miePhase(float cosTheta) {
	const float g  = 0.8;
	const float gg = g * g;

	const float p1 = (3.0 * (1.0 - gg)) / (2.0 * (2.0 + gg));
	float p2 = (cosTheta * cosTheta + 1.0) / pow(1.0 + gg - 2.0 * g * cosTheta, 1.5);

	return p1 * p2;
}
float rayleighPhase(float cosTheta) {
	return 0.75 * (cosTheta * cosTheta + 1.0);
}

vec3 skyAtmosphere(vec3 viewVec, vec3 sunVec) {
	float VoL = dot(viewVec, sunVec);
	float VoU = dot(viewVec, vec3(0.0, 0.0, 1.0));

	vec3 skyCol = max(pow(skyColor, vec3(GAMMA)), 1e-5 * vec3(0.15, 0.5, 1.0));

	float mie  = 3e-1 * miePhase(VoL);
	      mie *= dot(skyCol, vec3(0.2126, 0.7152, 0.0722));
	vec3  rayleigh = skyCol * rayleighPhase(VoL);
	return (rayleigh + mie) * (pow(saturate(1.0 - VoU), 4) * 6.5 + 0.5);
}

//--//

void main() {
	vec3 dir = unprojectSky(fragCoord);

	sky  = skyAtmosphere(dir, normalize(mat3(gbufferModelViewInverse) * shadowLightPosition).xzy);
	sky *= ILLUMINANCE_SKY;
}
