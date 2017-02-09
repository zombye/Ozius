materialStruct getMaterial(vec2 coord) {
	materialStruct material;

	vec4 diff = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).r));
	vec4 spec = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).g));

	material.diffuse   = pow(diff.rgb, vec3(GAMMA));
	material.specular  = vec3(min(spec.r * spec.r, 0.999));
	material.roughness = spec.b * spec.b;

	return material;
}
