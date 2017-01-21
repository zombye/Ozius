#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:0 */

layout (location = 0) out vec3 finalColor;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform sampler2D colortex3;

//--// Functions //--------------------------------------------------------------------------------------//

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
	finalColor = texture(colortex3, fragCoord).rgb;

	tonemap(finalColor);
	dither(finalColor);
}
