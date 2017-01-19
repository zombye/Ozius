#version 420

//--// Configuration //----------------------------------------------------------------------------------//

#include "/cfg/global.scfg"

const bool colortex5MipmapEnabled = true;

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:5 */

layout (location = 0) out vec3 composite; 

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec2 fragCoord;

in float exposure;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform sampler2D colortex5;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"

//--//

void main() {
	composite = texture(colortex5, fragCoord).rgb * exposure;
}
