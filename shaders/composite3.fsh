#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

#include "/cfg/bloom.scfg"

const bool colortex5MipmapEnabled = true;

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:54 */

layout (location = 0) out vec3 composite; 
layout (location = 1) out vec3 bloom;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

in float exposure;

//--// Uniforms //---------------------------------------------------------------------------------------//

#ifdef BLOOM
uniform float viewWidth, viewHeight;
#endif

uniform sampler2D colortex5;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"

//--//

#ifdef BLOOM
vec3 calculateBloomTile(vec2 coord, const int LOD) {
	if (any(greaterThan(abs(coord - 0.5), vec2(0.5)))) return vec3(0.0);

	vec3  bloomTile = vec3(0.0);
	float weights   = 0.0;

	for (float i = -BLOOM_RADIUS; i <= BLOOM_RADIUS; i++) {
		for (float j = -BLOOM_RADIUS; j <= BLOOM_RADIUS; j++) {
			vec2  offset = vec2(i, j);
			float weight = max(0.0, 1.0 - length(offset / BLOOM_RADIUS));

			if (weight > 0.0) {
				offset /= textureSize(colortex5, LOD);
				weight *= weight * weight;

				bloomTile += textureLod(colortex5, coord + offset, LOD).rgb * weight;
				weights   += weight;
			}
		}
	}

	return bloomTile / weights;
}

vec3 calculateBloomTiles() {
	vec2 px = 1.0 / vec2(viewWidth, viewHeight);

	vec3
	bloom  = calculateBloomTile((fragCoord - vec2(0.00000           , 0.00000           )) * exp2(1), 1);
	bloom += calculateBloomTile((fragCoord - vec2(0.00000           , 0.50000 + px.y * 2)) * exp2(2), 2);
	bloom += calculateBloomTile((fragCoord - vec2(0.25000 + px.x * 2, 0.50000 + px.y * 2)) * exp2(3), 3);
	bloom += calculateBloomTile((fragCoord - vec2(0.25000 + px.x * 2, 0.62500 + px.y * 4)) * exp2(4), 4);
	bloom += calculateBloomTile((fragCoord - vec2(0.31250 + px.x * 4, 0.62500 + px.y * 4)) * exp2(5), 5);
	bloom += calculateBloomTile((fragCoord - vec2(0.31250 + px.x * 4, 0.65625 + px.y * 6)) * exp2(6), 6);
	bloom += calculateBloomTile((fragCoord - vec2(0.46875 + px.x * 6, 0.65625 + px.y * 6)) * exp2(7), 7);

	return bloom;
}
#endif

vec3 lowLightAdapt(vec3 cone, float exposure) {
	float rod = dot(cone, vec3(15, 50, 35));
	rod *= 1.0 - pow(smoothstep(0.0, 4.0, rod), 0.01);

	return (rod + cone) * exposure;
}

void main() {
	composite = lowLightAdapt(texture(colortex5, fragCoord).rgb, exposure);

	#ifdef BLOOM
	bloom = lowLightAdapt(calculateBloomTiles(), exposure);
	#endif
}
