#version 420

//--// Structs //----------------------------------------------------------------------------------------//

struct worldStruct {
	vec3 globalLightVector;
	vec3 globalLightColor;

	vec3 upVector;
};

//--// Outputs //----------------------------------------------------------------------------------------//

out vec2 fragCoord;

out worldStruct world;

//--// Inputs //-----------------------------------------------------------------------------------------//

layout (location = 0) in vec4 vertexPosition;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform float sunAngle;

uniform vec3 shadowLightPosition;
uniform vec3 upPosition;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/illuminance.glsl"

//--//

void main() {
	gl_Position = vertexPosition * 2.0 - 1.0;
	fragCoord = vertexPosition.xy;

	//--// Fill world struct

	world.globalLightVector = normalize(shadowLightPosition);
	world.globalLightColor  = mix(vec3(0.2), vec3(ILLUMINANCE_SUN), sunAngle < 0.5);

	world.upVector = normalize(upPosition);
}
