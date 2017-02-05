#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

#include "/cfg/volumelight.scfg"

#define REFLECTION_SAMPLES 1 // [0 1 2 4 8 16]
#define REFLECTION_BOUNCES 1 // [1 2]

//--// Structs //----------------------------------------------------------------------------------------//

struct materialStruct {
	vec3 albedo;   // RGB of base texture.
	vec3 specular; // Currently R of specular texture.

	float roughness; // Currently B of specular texture
};

struct surfaceStruct {
	materialStruct material;

	vec3 normal;
	vec3 normalGeom;

	vec4 depth; // x = depth0, y = depth1 (depth0 without transparent objects). zw = linearized xy

	mat2x3 positionScreen; // Position in screen-space
	mat2x3 positionView;   // Position in view-space
	mat2x3 positionLocal;  // Position in local-space
};

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:5 */

layout (location = 0) out vec3 composite;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform int isEyeInWater;

uniform float eyeAltitude;

uniform float sunAngle;

uniform vec3 skyColor;

uniform vec3 shadowLightPosition;
uniform vec3 upPosition;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 shadowProjection, shadowModelView;

uniform sampler2D colortex0, colortex1;
uniform sampler2D colortex2, colortex3; // Transparent surfaces

uniform sampler2D colortex5; // Previous pass
uniform sampler2D colortex7; // Sky

uniform sampler2D depthtex0, depthtex1;

uniform sampler2DShadow shadowtex1;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"
#include "/lib/illuminance.glsl"

#include "/lib/util/packing/normal.glsl"
#include "/lib/util/maxof.glsl"
#include "/lib/util/noise.glsl"

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
vec3 viewSpaceToLocalSpace(vec3 viewSpace) {
	return (gbufferModelViewInverse * vec4(viewSpace, 1.0)).xyz;
}
vec3 viewSpaceToScreenSpace(vec3 viewSpace) {
	vec4 screenSpace = gbufferProjection * vec4(viewSpace, 1.0);
	return (screenSpace.xyz / screenSpace.w) * 0.5 + 0.5;
}

//--//

vec3 getSky(vec3 dir) {
	vec2 p = dir.xy * inversesqrt(dir.z * 8.0 + 8.0) * 2.0;
	p /= maxof(abs(normalize(p)));
	return texture(colortex7, p * 0.5 + 0.5).rgb;
}

//--//

vec3 f0ToIOR(vec3 f0) {
	f0 = sqrt(f0);
	return (1.0 + f0) / (1.0 - f0);
}

#include "/lib/reflectanceModels.glsl"

//--//

#include "/lib/composite/raytracer.fsh"

vec3 is(vec3 normal, vec3 noise, float roughness) {
	return normalize(normal + (noise * roughness));
}

vec3 calculateReflection(surfaceStruct surface) {
	float skyVis = unpackUnorm2x16(floatBitsToUint(textureRaw(colortex1, fragCoord).a)).y;

	vec3 reflection = vec3(0.0);
	const uint samples = REFLECTION_SAMPLES;
	const uint bounces = REFLECTION_BOUNCES;
	for (uint i = 0; i < samples; i++) {
		vec3 rayDir = normalize(surface.positionView[1]);

		materialStruct hitMaterial = surface.material;
		vec3 hitNormal = is(surface.normal, normalize(noise3(fragCoord + i) * 2.0 - 1.0), hitMaterial.roughness);

		vec3 reflColor = vec3(1.0);
		vec3 hitCoord  = surface.positionScreen[1];
		vec3 hitPos    = surface.positionView[1];

		for (uint j = 0; j < bounces; j++) {
			reflColor *= f_fresnel(max(dot(hitNormal, -rayDir), 0.0), hitMaterial.specular);
			if (reflColor == 0.0) break;

			rayDir = reflect(rayDir, hitNormal);

			if (raytraceIntersection(hitPos, rayDir, hitCoord, hitPos)) {
				reflection += texture(colortex5, hitCoord.st).rgb * reflColor;
			} else if (skyVis > 0) {
				reflection += getSky((mat3(gbufferModelViewInverse) * rayDir).xzy) * skyVis * reflColor;
			}

			if (i < samples) {
				hitMaterial = getMaterial(hitCoord.st);
				hitNormal   = is(getNormal(hitCoord.st), normalize(noise3(fragCoord + i) * 2.0 - 1.0), hitMaterial.roughness);
			}
		}
	}

	if (any(isnan(reflection))) reflection = vec3(0.0);

	return reflection / samples;
}

//--//

vec3 waterFog(vec3 col, float dist) {
	const vec3  fogColor   = vec3(0.1, 0.6, 0.9);
	const float fogDensity = 0.4;

	return col * exp(-dist * (fogDensity / fogColor));
}

vec3 calculateWaterShading(surfaceStruct surface) {
	vec3 tex3Raw = textureRaw(colortex3, fragCoord).rgb;

	vec3 viewDir = normalize(surface.positionView[0]);

	vec3  normal = unpackNormal(tex3Raw.r);
	float skyVis = tex3Raw.b;

	vec3 f = saturate(f_fresnel(dot(normal, -viewDir), vec3(0.02)));

	// Reflections
	vec3 reflection = vec3(0.0); {
		vec3 rayDir = reflect(viewDir, normal);

		vec3 hitCoord;
		vec3 hitPos;
		if (raytraceIntersection(surface.positionView[0], rayDir, hitCoord, hitPos)) {
			reflection = texture(colortex5, hitCoord.xy).rgb;
		} else if (skyVis > 0 && isEyeInWater == 0) {
			reflection = getSky((mat3(gbufferModelViewInverse) * rayDir).xzy) * skyVis;
		}

		if (isEyeInWater == 1) {
			reflection = waterFog(reflection, distance(surface.positionView[0], hitPos));

			// Needed because hitPos sometimes gets bad values.
			if (isnan(reflection.r)) reflection = vec3(0.0);
		}
	}

	// Refractions
	vec3 refraction; {
		vec3 rayDir = refract(viewDir, normal, 0.75);

		float refractAmount = saturate(distance(surface.positionView[0], surface.positionView[1]));

		vec3 hitPos   = rayDir * refractAmount + surface.positionView[1];
		vec3 hitCoord = viewSpaceToScreenSpace(hitPos);

		if (texture(depthtex1, hitCoord.xy) == 1.0) {
			refraction = getSky((mat3(gbufferModelViewInverse) * rayDir).xzy);
		} else {
			refraction = texture(colortex5, hitCoord.xy).rgb;
		}

		if (isEyeInWater == 0) {
			refraction = waterFog(refraction, distance(surface.positionView[0], hitPos) - refractAmount);
		}
	}

	vec3 waterShading = mix(refraction, reflection, f);

	if (isEyeInWater == 1) {
		waterShading = waterFog(waterShading, length(surface.positionView[0]));
	}

	return waterShading;
}

//--//

#ifdef VL
float miePhase(float cosTheta) {
	const float g  = 0.8;
	const float gg = g * g;

	float p1 = (3.0 * (1.0 - gg)) / (2.0 * (2.0 + gg));
	float p2 = ((cosTheta * cosTheta) + 1.0) / pow(1.0 + gg - 2.0 * g * cosTheta, 1.5);

	return p1 * p2;
}
float rayleighPhase(float cosTheta) {
	return 0.75 * (cosTheta * cosTheta + 1.0);
}

vec3 localSpaceToShadowSpace(vec3 localPos) {
	vec3 shadowPos = (shadowProjection * shadowModelView * vec4(localPos, 1.0)).xyz;
	return vec3(shadowPos.xy / (1.0 + length(shadowPos.xy)), shadowPos.z / 4.0);
}

vec3 calculateVolumetricLight(vec3 color, vec3 viewVector, float linearDepth) {
	const uint  maxSteps = VL_STEPS;
	const float maxDist  = VL_MAX_DISTANCE;
	float stepSize = min(maxDist, linearDepth / viewVector.z) / maxSteps;

	// 0/x = rayleigh, 1/y = mie
	mat2x3 coeffMatrix = mat2x3(pow(skyColor, vec3(GAMMA)) * 5e-5, vec3(3e-6));

	float VoL = dot(viewVector, normalize(shadowLightPosition));
	vec2 phase = vec2(rayleighPhase(VoL), miePhase(VoL));

	vec3 increment = viewVector * stepSize;

	vec3 viewPos = -increment * noise1(fragCoord);
	vec3 transmittance = vec3(1.0);
	vec3 scattered     = vec3(0.0);
	for (uint i = 0; i < maxSteps; i++) {
		viewPos += increment;
		vec3 localPos = viewSpaceToLocalSpace(viewPos);

		vec2 odStep = exp(-(localPos.y + eyeAltitude) / vec2(8e3, 1.2e3)) * stepSize;

		transmittance *= exp(coeffMatrix * -odStep); // using double precition here could help, as it can round to 0 if odStep is too small

		scattered += (coeffMatrix * (odStep * phase)) * transmittance * texture(shadowtex1, localSpaceToShadowSpace(localPos) * 0.5 + 0.5);
	}
	scattered *= VL_MULT * mix(0.2, ILLUMINANCE_SUN, sunAngle < 0.5);

	return mix(scattered, color, transmittance);
}
#endif

//--//

void main() {
	surfaceStruct surface;

	surface.depth.x = texture(depthtex0, fragCoord).r;
	surface.depth.y = texture(depthtex1, fragCoord).r;

	surface.positionScreen[0] = vec3(fragCoord, surface.depth.x);
	surface.positionScreen[1] = vec3(fragCoord, surface.depth.y);
	surface.positionView[0]   = screenSpaceToViewSpace(surface.positionScreen[0]);
	surface.positionView[1]   = screenSpaceToViewSpace(surface.positionScreen[1]);
	surface.positionLocal[0]  = viewSpaceToLocalSpace(surface.positionView[0]);
	surface.positionLocal[1]  = viewSpaceToLocalSpace(surface.positionView[1]);

	if (surface.depth.y == 1.0) {
		if (texture(colortex3, fragCoord).a > 0.0) {
			composite = calculateWaterShading(surface);
		} else {
			composite = getSky(normalize(surface.positionLocal[0].xzy));

			if (isEyeInWater == 1) {
				composite = waterFog(composite, length(surface.positionView[0]));
			}
		}

		vec4 trans = texture(colortex2, fragCoord);
		composite = mix(composite, trans.rgb, trans.a);
		return;
	}

	surface.depth.z = linearizeDepth(surface.depth.x);
	surface.depth.w = linearizeDepth(surface.depth.y);

	surface.material = getMaterial(fragCoord);

	surface.normal     = getNormal(fragCoord);
	surface.normalGeom = getNormalGeom(fragCoord);

	composite = texture(colortex5, fragCoord).rgb;

	bool waterMask = texture(colortex3, fragCoord).a > 0.0;

	#if REFLECTION_SAMPLES > 0
	if (any(greaterThan(surface.material.specular, vec3(0.0))) && !waterMask) {
		composite *= saturate(1.0 - f_fresnel(max(dot(surface.normal, -normalize(surface.positionView[0])), 0.0), surface.material.specular));
		composite += calculateReflection(surface);
	}
	#endif

	if (waterMask) {
		composite = calculateWaterShading(surface);
	} else if (isEyeInWater == 1) {
		composite = waterFog(composite, length(surface.positionView[0]));
	}

	#ifdef VL
	composite = calculateVolumetricLight(composite, normalize(surface.positionView[0]), surface.depth.z);
	#endif

	if (waterMask) composite /= 0.8; // Water needs some opacity to render, this hides the effects of that.

	vec4 trans = texture(colortex2, fragCoord);
	composite = mix(composite, trans.rgb, trans.a);
}
