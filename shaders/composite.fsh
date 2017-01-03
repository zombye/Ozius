#version 400

//--// Configuration //----------------------------------------------------------------------------------//
/*
const int colortex0Format = RGBA16;
const int colortex1Format = RGBA16;
const int colortex2Format = RGBA16;
*/
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

layout (location = 0) out vec3 composite;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform vec3 shadowLightPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

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
	vec4 normal = vec4(texture(colortex2, coord).rg * 2.0 - 1.0, 1.0, -1.0);
	normal.z    = dot(normal.xyz, -normal.xyw);
	normal.xy  *= sqrt(normal.z);
	return normal.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}

float fresnel_schlick(float NoI, float f0) {
	return saturate(mix(pow(1.0 - NoI, 5.0), 1.0, f0));
}

// Converts R0 to an IOR.
// kn is a known IOR, and should be what was used to calculate the value for f0.
float R0ToIOR(float R0, float kn) {
	float cn = sqrt(R0);
	return (kn + cn) / (kn - cn);
}
float R0ToIOR(float R0) {
	const float kn = 1.0003;

	float cn = sqrt(R0);
	return (kn + cn) / (kn - cn);
}

float linearizeDepth(float depth) {
	return 1.0 / ((depth * 2.0 - 1.0) * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}
vec3 screenSpaceToViewSpace(vec3 screenSpace) {
	vec4 viewSpace = gbufferProjectionInverse * vec4(screenSpace * 2.0 - 1.0, 1.0);
	return viewSpace.xyz / viewSpace.w;
}
vec3 viewSpaceToLocalSpace(vec3 viewSpace) {
	return (gbufferModelViewInverse * vec4(viewSpace, 1.0)).xyz;
}

void main() {
	surfaceStruct surface;

	surface.material = getMaterial(fragCoord);

	surface.normal = getNormal(fragCoord);

	surface.depth.x = texture(depthtex0, fragCoord).r;
	surface.depth.y = texture(depthtex1, fragCoord).r;
	surface.depth.z = linearizeDepth(surface.depth.x);
	surface.depth.w = linearizeDepth(surface.depth.y);

	surface.positionScreen[0] = vec3(fragCoord, surface.depth.x);
	surface.positionScreen[1] = vec3(fragCoord, surface.depth.y);
	surface.positionView[0]   = screenSpaceToViewSpace(surface.positionScreen[0]);
	surface.positionView[1]   = screenSpaceToViewSpace(surface.positionScreen[1]);
	surface.positionLocal[0]  = viewSpaceToLocalSpace(surface.positionView[0]);
	surface.positionLocal[1]  = viewSpaceToLocalSpace(surface.positionView[1]);

	vec3 vv  = normalize(surface.positionView[0]);
	vec3 rvv = refract(vv, surface.normal, 1.0003 / R0ToIOR(surface.material.clearcoat));

	float frb = fresnel_schlick(dot(-rvv, surface.normal), surface.material.specular);
	float frc = fresnel_schlick(dot(-vv,  surface.normal), surface.material.clearcoat);

	composite = mix(mix(surface.material.albedo, vec3(0.15, 0.5, 1.0), frb), vec3(0.15, 0.5, 1.0), frc);
}
