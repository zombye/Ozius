#version 420

//--// Outputs //----------------------------------------------------------------------------------------//

/* DRAWBUFFERS:0 */

layout (location = 0) out vec4 packedMaterial;

//--// Inputs //-----------------------------------------------------------------------------------------//

in vec4 color;

//--// Functions //--------------------------------------------------------------------------------------//

void main() {
	packedMaterial.r = uintBitsToFloat(packUnorm4x8(color));
	packedMaterial.g = uintBitsToFloat(0x000000ff);
	packedMaterial.b = uintBitsToFloat(0x000000ff);
	packedMaterial.a = 1.0;
}
