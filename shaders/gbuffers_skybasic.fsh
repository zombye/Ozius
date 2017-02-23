#version 420

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:7 */

layout (location = 0) out vec4 sky;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

in vec3 sunDir, moonDir;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform float eyeAltitude;

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

// Ray-sphere intersection
vec2 rsi(vec3 pos, vec3 dir, float radSq) {
	float rDot  = dot(pos, dir);
	float delta = sqrt((rDot * rDot) - dot(pos, pos) + radSq);
	return -rDot + vec2(delta, -delta);
}
bool rsib(vec3 pos, vec3 dir, float radSq) {
	float rDot  = dot(pos, dir);
	float delta = (rDot * rDot) - dot(pos, pos) + radSq;
	return delta >= 0.0 && (rDot <= 0.0 || dot(pos, pos) <= radSq);
}

vec3 skyAtmosphere(vec3 viewDir) {
	//--// Constants

	const uint iSteps = 16;
	const uint jSteps = 2; // 2 is pretty much the minimum that's somewhat accurate

	const vec3 sunLightCol  = vec3(ILLUMINANCE_SUN);
	const vec3 moonLightCol = vec3(0.2);

	const float planetRadius = 6371e3;
	const float atmosRadius  = planetRadius + 100e3;
	const vec2 scaleHeightsRcp = 1.0 / vec2(8e3, 1.2e3);
	const vec2 radiiSqrd = vec2(planetRadius * planetRadius, atmosRadius * atmosRadius);
	const mat2x3 coeffMatrix = mat2x3(vec3(5.8e-6, 1.35e-5, 3.31e-5), vec3(6e-6));

	//--//

	if (viewDir.z < -0.2) return vec3(0.0);

	vec3 pos = vec3(0.0, 0.0, planetRadius + eyeAltitude);

	float iStep = rsi(pos, viewDir, radiiSqrd.y).x / iSteps;
	vec3  iIncr = viewDir * iStep;
	vec3  iPos  = iIncr * -0.5 + pos;

	float sunVoL    = dot(viewDir, sunDir);
	float moonVoL   = dot(viewDir, moonDir);
	vec2  sunPhase  = vec2(rayleighPhase(sunVoL), miePhase(sunVoL));
	vec2  moonPhase = vec2(rayleighPhase(moonVoL), miePhase(moonVoL));

	vec2 odI         = vec2(0.0);
	vec3 sunScatter  = vec3(0.0);
	vec3 moonScatter = vec3(0.0);
	for (uint i = 0; i < iSteps; i++) {
		iPos += iIncr;

		vec2 odIStep = exp(-(length(iPos) - planetRadius) * scaleHeightsRcp) * iStep;

		odI += odIStep;

		// Sun
		{
			float jStep = rsi(iPos, sunDir, radiiSqrd.y).x / jSteps;
			vec3  jIncr = sunDir * jStep;
			vec3  jPos  = jIncr * -0.5 + iPos;

			vec2 odJ = vec2(0.0);
			for (float j = 0.0; j < jSteps; j++) {
				jPos += jIncr;
				odJ  += exp(-(length(jPos) - planetRadius) * scaleHeightsRcp) * jStep;
			}

			sunScatter += (coeffMatrix * (odIStep * sunPhase)) * exp(coeffMatrix * -(odI + odJ));
		}

		// Moon
		{
			float jStep = rsi(iPos, moonDir, radiiSqrd.y).x / jSteps;
			vec3  jIncr = moonDir * jStep;
			vec3  jPos  = jIncr * -0.5 + iPos;

			vec2 odJ = vec2(0.0);
			for (float j = 0.0; j < jSteps; j++) {
				jPos += jIncr;
				odJ  += exp(-(length(jPos) - planetRadius) * scaleHeightsRcp) * jStep;
			}

			moonScatter += (coeffMatrix * (odIStep * moonPhase)) * exp(coeffMatrix * -(odI + odJ));
		}
	}

	if (any(isnan(sunScatter))) sunScatter = vec3(0.0);
	if (any(isnan(moonScatter))) moonScatter = vec3(0.0);

	return (sunScatter*sunScatter * sunLightCol) + (moonScatter*moonScatter * moonLightCol);
}

//--//

void main() {
	sky.rgb = skyAtmosphere(unprojectSky(fragCoord));
	sky.a = 1.0;
}
