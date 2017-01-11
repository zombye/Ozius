float packNormal(vec3 normal) {
	return uintBitsToFloat(packUnorm2x16(normal.xy * inversesqrt(normal.z * 8.0 + 8.0) + 0.5));
}
vec3 unpackNormal(float pack) {
	vec4 normal = vec4(unpackUnorm2x16(floatBitsToUint(pack)) * 2.0 - 1.0, 1.0, -1.0);
	normal.z    = dot(normal.xyz, -normal.xyw);
	normal.xy  *= sqrt(normal.z);
	return normal.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}
