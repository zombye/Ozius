#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

//--// Structs //----------------------------------------------------------------------------------------//

struct materialStruct {
	vec3  albedo;    // RGB of base texture.
	float specular;  // Specular R channel. In SEUS v11.0: Specularity
	float metallic;  // Specular G channel. In SEUS v11.0: Additive rain specularity
	float roughness; // Specular B channel. In SEUS v11.0: Roughness / Glossiness
	float clearcoat; // Specular A channel. In SEUS v11.0: Unused
	float dR;
	float dG;
	float dB;
	float dA;
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

uniform vec3 shadowLightPosition;
uniform vec3 upPosition;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform sampler2D colortex0, colortex1;
uniform sampler2D colortex2, colortex3; // Transparent surfaces

uniform sampler2D colortex5; // Previous pass
uniform sampler2D colortex7; // Sky

uniform sampler2D depthtex0, depthtex1;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"

#include "/lib/util/packing/normal.glsl"

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

#include "/lib/projection.glsl"

vec3 getSky(vec3 dir) {
	return texture(colortex7, equirectangleForward(dir)).rgb;
}

//--//

float f0ToIOR(float f0) {
	f0 = sqrt(f0);
	return (1.0 + f0) / (1.0 - f0);
}

#include "/lib/reflectanceModels.glsl"

#include "/lib/composite/raytracer.fsh"

vec3 calculateReflection(surfaceStruct surface) {
	vec3 viewDir = normalize(surface.positionView[1]);

	float skyVis = unpackUnorm2x16(floatBitsToUint(textureRaw(colortex1, fragCoord).a)).y;

	vec3 reflection = vec3(0.0);
	const uint samples = 1;
	const uint bounces = 1;
	for (uint i = 0; i < samples; i++) {
		vec3 normal = surface.normal;
		vec3 rayDir = reflect(viewDir, normal);
		for (uint j = 0; j < bounces; j++) {
			// TODO

			if (j < bounces) {
				// Get info required for next raytrace
			}
		}

		float NoO = dot(normal, -viewDir);
		vec3 mul = mix(vec3(1.0), surface.material.albedo, surface.material.metallic) * f_fresnel(NoO, surface.material.specular);

		vec3 reflectedCoord;
		vec3 reflectedPos;
		if (raytraceIntersection(surface.positionView[1], rayDir, reflectedCoord, reflectedPos)) {
			reflection += texture(colortex5, reflectedCoord.xy).rgb * mul;
		} else if (skyVis > 0) {
			reflection += getSky((mat3(gbufferModelViewInverse) * rayDir).xzy) * skyVis * mul;
		}
	}

	return reflection / samples;
}

//--//

vec3 waterFog(vec3 col, float dist) {
	const vec3  fogColor   = vec3(0.1, 0.6, 0.9);
	const float fogBright  = 4e2;
	const float fogDensity = 0.4;

	return mix(fogColor * fogBright, col, exp(-dist * (fogDensity / fogColor)));
}

vec3 calculateWaterShading(surfaceStruct surface) {
	vec3 tex3Raw = textureRaw(colortex3, fragCoord).rgb;

	vec3 viewDir = normalize(surface.positionView[0]);

	vec3  normal = unpackNormal(tex3Raw.r);
	float skyVis = tex3Raw.b;

	float f;

	// Reflections
	vec3 reflection = vec3(0.0);
	{
		vec3 rayDir = reflect(viewDir, normal);

		f = saturate(f_fresnel(dot(normal, -viewDir), 0.02));

		vec3 hitCoord;
		vec3 hitPos;
		if (raytraceIntersection(surface.positionView[0], rayDir, hitCoord, hitPos)) {
			reflection = texture(colortex5, hitCoord.xy).rgb;
		} else if (skyVis > 0) {
			reflection = getSky((mat3(gbufferModelViewInverse) * rayDir).xzy) * skyVis;
		}

		if (isEyeInWater == 1) {
			reflection = waterFog(reflection, distance(surface.positionView[0], hitPos));
		}
	}

	// Refractions
	vec3 refraction = vec3(0.0);
	{
		// TODO
		vec3 rayDir = refract(viewDir, normal, isEyeInWater > 0 ? 1.33 : 0.75);

		vec3 hitCoord = surface.positionScreen[0];
		vec3 hitPos   = surface.positionView[1];

		refraction = texture(colortex5, hitCoord.xy).rgb;

		if (isEyeInWater == 0) {
			refraction = waterFog(refraction, distance(surface.positionView[0], hitPos));
		}
	}

	vec3 waterShading = mix(refraction, reflection, f);

	if (isEyeInWater == 1) {
		waterShading = waterFog(waterShading, length(surface.positionView[0]));
	}

	return waterShading;
}

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
	if (surface.material.specular > 0.0) {
		composite *= (1.0 - f_fresnel(dot(surface.normal, -normalize(surface.positionView[0])), surface.material.specular));
		composite += calculateReflection(surface);
	}

	if (texture(colortex3, fragCoord).a > 0.0) {
		composite = calculateWaterShading(surface);
	} else if (isEyeInWater == 1) {
		composite = waterFog(composite, length(surface.positionView[0]));
	}

	vec4 trans = texture(colortex2, fragCoord);
	composite = mix(composite, trans.rgb, trans.a);
}
