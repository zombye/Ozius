#version 420 compatibility

//--// Outputs //----------------------------------------------------------------------------------------//

out vec4 tint;
out vec2 baseUV;
out vec3 vertNormal;

//--// Inputs //-----------------------------------------------------------------------------------------//

layout (location = 0)  in vec4 vertexPosition;
layout (location = 2)  in vec3 vertexNormal;
layout (location = 3)  in vec4 vertexColor;
layout (location = 8)  in vec2 vertexUV;
layout (location = 9)  in vec2 vertexLightmap;
layout (location = 10) in vec4 vertexMetadata;
layout (location = 11) in vec2 quadMidUV;

//--// Uniforms //---------------------------------------------------------------------------------------//

uniform float rainStrength;

uniform vec3 cameraPosition;

uniform mat4 shadowModelView, shadowProjection;
uniform mat4 shadowModelViewInverse;

uniform sampler2D noisetex;

//--// Functions //--------------------------------------------------------------------------------------//

#include "/lib/preprocess.glsl"
#include "/lib/time.glsl"

#include "/lib/util/textureBicubic.glsl"
#include "/lib/util/textureSmooth.glsl"

//--//

#include "/lib/gbuffers/initPosition.vsh"

//--//

#include "/lib/gbuffers/displacement.vsh"

//--//

void main() {
	if (abs(vertexMetadata.x - 8.5) < 0.6) {
		gl_Position = vec4(1.0);
		return;
	}

	gl_Position = initPosition();
	gl_Position = shadowModelViewInverse * gl_Position;

	gl_Position.xyz += cameraPosition;
	calculateDisplacement(gl_Position.xyz);
	gl_Position.xyz -= cameraPosition;

	gl_Position = shadowProjection * shadowModelView  * gl_Position;

	gl_Position.xyz /= vec3(vec2(1.0 + length(gl_Position.xy)), 4.0);

	tint   = vertexColor;
	baseUV = vertexUV;
	vertNormal = gl_NormalMatrix * vertexNormal;
}
