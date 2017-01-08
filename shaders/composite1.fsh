#version 400

//--// Configuration //----------------------------------------------------------------------------------//

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

	vec4 depth; // x = depth0, y = depth1 (depth0 without transparent objects). zw = linearized xy

	mat2x3 positionScreen; // Position in screen-space
	mat2x3 positionView;   // Position in view-space
	mat2x3 positionLocal;  // Position in local-space
};

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:0 */

layout (location = 0) out vec3 composite;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform vec3 shadowLightPosition;
uniform vec3 upPosition;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform sampler2D colortex6; // Previous pass
uniform sampler2D colortex7; // Sky

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"

materialStruct getMaterial(vec2 coord) {
	materialStruct material;

	vec4 tex0 = texture(colortex0, coord);
	vec4 tex1 = texture(colortex1, coord);

	material.albedo    = tex0.rgb;
	material.specular  = tex1.r;
	material.metallic  = tex1.g;
	material.roughness = tex1.b;
	material.clearcoat = tex1.a;

	return material;
}
vec3 getNormal(vec2 coord) {
	vec2 unpack = unpackUnorm2x16(floatBitsToUint(textureRaw(colortex2, coord).r));
	vec4 normal = vec4(unpack * 2.0 - 1.0, 1.0, -1.0);
	normal.z    = dot(normal.xyz, -normal.xyw);
	normal.xy  *= sqrt(normal.z);
	return normal.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}
vec3 getNormalGeom(vec2 coord) {
	vec2 unpack = unpackUnorm2x16(floatBitsToUint(textureRaw(colortex2, coord).g));
	vec4 normal = vec4(unpack * 2.0 - 1.0, 1.0, -1.0);
	normal.z    = dot(normal.xyz, -normal.xyw);
	normal.xy  *= sqrt(normal.z);
	return normal.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}

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
	vec2 coord = equirectangleForward(dir);

	return texture(colortex7, coord).rgb;
}

//--//

#include "/lib/reflectanceModels.glsl"

vec3 blendMaterial(vec3 diffuse, vec3 specular, materialStruct material) {
	diffuse = material.albedo * diffuse;

	vec3 dielectric = specular + diffuse;
	vec3 metal      = specular * material.albedo;

	return mix(dielectric, metal, material.metallic);
}

float f0ToIOR(float f0) {
	f0 = sqrt(f0);
	return (1.0 + f0) / (1.0 - f0);
}
float f0FromIOR(float n1, float n2) {
	n1 = (n1 - n2) / (n1 + n2);
	return n1 * n1;
}
float f0FromIOR(float n) {
	n = (1.0 - n) / (1.0 + n);
	return n * n;
}

bool raytraceIntersection(vec3 pos, vec3 vec, out vec3 screenSpace) {
	const float maxSteps  = 32;
	const float stepSize  = 0.5;
	const float stepScale = 1.6;

	pos = pos + (vec * stepSize);

	for (uint i = 0; i < maxSteps; i++) {
		vec3 viewSpace   = pos + (vec * pow(i, stepScale) * stepSize);
		     screenSpace = viewSpaceToScreenSpace(viewSpace);

		if (any(greaterThan(abs(screenSpace - 0.5), vec3(0.5)))) return false;

		float screenZ = texture(depthtex1, screenSpace.xy).r;
		float diff = viewSpace.z - linearizeDepth(screenZ);

		if (diff < 0.0) {
			vec3 samplePos  = screenSpaceToViewSpace(vec3(screenSpace.xy, screenZ));
			vec3 sampleNorm = getNormalGeom(screenSpace.xy);

			// Assuming we've found the right plane, this will put the positions exactly where the ray intersects it.
			viewSpace  += vec * (dot(samplePos - viewSpace, sampleNorm) / dot(vec, sampleNorm));
			screenSpace = viewSpaceToScreenSpace(viewSpace);

			if (any(greaterThan(abs(screenSpace - 0.5), vec3(0.5)))) return false;

			return true;
		}
	}

	return false;
}

vec3 calculateReflection(surfaceStruct surface) {
	vec3 viewDir = normalize(surface.positionView[1]);

	float skyVis = texture(colortex2, fragCoord).a;

	vec3 reflection = vec3(0.0);
	const uint samples = 1;
	for (uint i = 0; i < samples; i++) {
		vec3 normal = surface.normal;
		vec3 rayDir = reflect(viewDir, normal);

		vec3 reflectedCoord;
		if (raytraceIntersection(surface.positionView[1], rayDir, reflectedCoord)) {
			reflection += texture(colortex6, reflectedCoord.xy).rgb;
		} else if (skyVis > 0) {
			reflection += getSky((mat3(gbufferModelViewInverse) * rayDir).xzy) * skyVis;
		}
	}

	return reflection / samples;
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

	if (surface.depth.x == 1.0) {
		composite = getSky(normalize(surface.positionLocal[0].xzy));
		return;
	}

	surface.depth.z = linearizeDepth(surface.depth.x);
	surface.depth.w = linearizeDepth(surface.depth.y);

	surface.material = getMaterial(fragCoord);

	surface.normal = getNormal(fragCoord);

	float NoV = dot(surface.normal, -normalize(surface.positionView[0]));

	composite = texture(colortex6, fragCoord).rgb * (1.0 - f_schlick(NoV, surface.material.specular));
	vec3 reflection = calculateReflection(surface) * f_schlick(NoV, surface.material.specular);

	composite = blendMaterial(composite, reflection, surface.material);
}
