materialStruct getMaterial(vec2 coord) {
	materialStruct material;

	vec4 diff = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).r));
	vec4 spec = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).g));
	vec4 emis = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).b));

	material.diffuse   = pow(diff.rgb, vec3(GAMMA));
	material.specular  = spec.rgb;
	material.emission  = pow(emis.rgb, vec3(GAMMA));

	return material;
}
