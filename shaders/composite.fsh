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

const int colortex5Format = RGBA32F;

const int colortex7Format = RGBA32F; // Sky
*/

const bool shadowHardwareFiltering0 = true;
const bool shadowHardwareFiltering1 = true;

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:7 */

layout (location = 0) out vec3 sky;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform vec3 shadowLightPosition;

uniform mat4 gbufferModelViewInverse;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"
#include "/lib/illuminance.glsl"

//--//

#include "/lib/projection.glsl"

float miePhase(float cosTheta) {
	const float g  = 0.9;
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
#include "/lib/composite/sky/atmosphere.fsh"

#include "/lib/composite/sky/calculateSky.fsh"

//--//

void main() {
	sky = calculateSky(fragCoord);
}
