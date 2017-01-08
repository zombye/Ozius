#version 400

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:0 */

layout (location = 0) out vec4 data0;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec4 color;

//--// Functions //--------------------------------------------------------------------------------------//

void main() {
	data0.r = uintBitsToFloat(packUnorm4x8(color));
	data0.g = uintBitsToFloat(0x000000ff);
	data0.b = uintBitsToFloat(0x000000ff);
	data0.a = 1.0;
}
