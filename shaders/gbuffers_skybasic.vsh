#version 420

//--// Outputs //---------------------------------------------------------------------------------------//

out vec2 fragCoord;

//--// Functions //--------------------------------------------------------------------------------------//

void main() {
	const vec4[3] verts = vec4[3](
		vec4(-1.0, -1.0, 0.9, 1.0),
		vec4( 3.0, -1.0, 0.9, 1.0),
		vec4(-1.0,  3.0, 0.9, 1.0)
	);
	const vec2[3] coords = vec2[3](
		vec2(0.0, 0.0),
		vec2(2.0, 0.0),
		vec2(0.0, 2.0)
	);

	gl_Position = verts[gl_VertexID % 3];
	gl_Position.z += floor(gl_VertexID / 3); // Prevents overdraw. Pretty important for performance.
	fragCoord = coords[int(mod(float(gl_VertexID), 3.0))];
}
