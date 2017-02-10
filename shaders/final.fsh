#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

#include "/cfg/bloom.scfg"

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:0 */

layout (location = 0) out vec3 finalColor;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

#ifdef BLOOM
uniform float viewWidth, viewHeight;
#endif

#ifdef BLOOM
uniform sampler2D colortex4;
#endif
uniform sampler2D colortex5;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/util/textureBicubic.glsl"

//--//

#ifdef BLOOM
void applyBloom(inout vec3 color) {
	const float[7] weight = float[7](
		pow(1, -BLOOM_CURVE),
		pow(2, -BLOOM_CURVE),
		pow(3, -BLOOM_CURVE),
		pow(4, -BLOOM_CURVE),
		pow(5, -BLOOM_CURVE),
		pow(6, -BLOOM_CURVE),
		pow(7, -BLOOM_CURVE)
	);
	const float weights = weight[0] + weight[1] + weight[2] + weight[3] + weight[4] + weight[5] + weight[6];

	vec2 px = 1.0 / vec2(viewWidth, viewHeight);

	vec3
	bloom  = textureBicubic(colortex4, (fragCoord / exp2(1)) + vec2(0.00000           , 0.00000           )).rgb * weight[0];
	bloom += textureBicubic(colortex4, (fragCoord / exp2(2)) + vec2(0.00000           , 0.50000 + px.y * 2)).rgb * weight[1];
	bloom += textureBicubic(colortex4, (fragCoord / exp2(3)) + vec2(0.25000 + px.x * 2, 0.50000 + px.y * 2)).rgb * weight[2];
	bloom += textureBicubic(colortex4, (fragCoord / exp2(4)) + vec2(0.25000 + px.x * 2, 0.62500 + px.y * 4)).rgb * weight[3];
	bloom += textureBicubic(colortex4, (fragCoord / exp2(5)) + vec2(0.31250 + px.x * 4, 0.62500 + px.y * 4)).rgb * weight[4];
	bloom += textureBicubic(colortex4, (fragCoord / exp2(6)) + vec2(0.31250 + px.x * 4, 0.65625 + px.y * 6)).rgb * weight[5];
	bloom += textureBicubic(colortex4, (fragCoord / exp2(7)) + vec2(0.46875 + px.x * 6, 0.65625 + px.y * 6)).rgb * weight[6];
	bloom /= weights;

	color = mix(color, bloom, BLOOM_AMOUNT * 0.5);
}
#endif

void tonemap(inout vec3 color) {
	color *= color;
	color /= color + 1.0;
	color  = pow(color, vec3(0.5 / GAMMA));
}
void dither(inout vec3 color) {
	const mat4 pattern = mat4(
		 1,  9,  3, 11,
		13,  5, 15,  7,
		 4, 12,  2, 10,
		16,  8, 14,  6
	) / (255 * 17);

	ivec2 p = ivec2(mod(gl_FragCoord.st, 4.0));

	color += pattern[p.x][p.y];
}

void main() {
	finalColor = texture(colortex5, fragCoord).rgb;

	#ifdef BLOOM
	applyBloom(finalColor);
	#endif

	tonemap(finalColor);
	dither(finalColor);
}
