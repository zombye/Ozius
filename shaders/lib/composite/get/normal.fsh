vec3 getNormal(vec2 coord) {
	vec2 unpack = unpackUnorm2x16(floatBitsToUint(textureRaw(colortex1, coord).r));
	vec4 normal = vec4(unpack * 2.0 - 1.0, 1.0, -1.0);
	normal.z    = dot(normal.xyz, -normal.xyw);
	normal.xy  *= sqrt(normal.z);
	return normal.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}
vec3 getNormalGeom(vec2 coord) {
	vec2 unpack = unpackUnorm2x16(floatBitsToUint(textureRaw(colortex1, coord).g));
	vec4 normal = vec4(unpack * 2.0 - 1.0, 1.0, -1.0);
	normal.z    = dot(normal.xyz, -normal.xyw);
	normal.xy  *= sqrt(normal.z);
	return normal.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}
