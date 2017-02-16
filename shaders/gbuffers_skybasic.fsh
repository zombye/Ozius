#version 420

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:7 */

layout (location = 0) out vec4 sky;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

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

	vec3 skyCol = max(ILLUMINANCE_SKY * pow(skyColor, vec3(2.2)), 0.0175 * vec3(0.15, 0.5, 1.0));

	float mie  = 3e-1 * miePhase(VoL);
	      mie *= dot(skyCol, vec3(0.2126, 0.7152, 0.0722));
	vec3  rayleigh = skyCol * rayleighPhase(VoL);
	return (rayleigh + mie) * (pow(saturate(1.0 - VoU), 4) * 6.5 + 0.5);
}

//--//

void main() {
	sky.rgb = skyAtmosphere(unprojectSky(fragCoord), normalize(mat3(gbufferModelViewInverse) * shadowLightPosition).xzy);
	sky.a = 1.0;
}
