#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:34 */

layout (location = 0) out vec3 composite;
layout (location = 1) out vec3 prevComposite;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform sampler2D colortex2, colortex3, colortex4;

//--// Functions //--------------------------------------------------------------------------------------//

void main() {
	vec4 trans = texture(colortex2, fragCoord);
	composite = mix(texture(colortex3, fragCoord).rgb, trans.rgb, trans.a);
	prevComposite = texture(colortex4, fragCoord).rgb;
}
