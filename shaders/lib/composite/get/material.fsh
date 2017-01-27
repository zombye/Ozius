materialStruct getMaterial(vec2 coord) {
	materialStruct material;

	vec4 diff = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).r));
	vec4 spec = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).g));

	material.albedo    = pow(diff.rgb, vec3(GAMMA));
	material.specular  = min(pow(spec.rgb, vec3(2.0)), 0.999);
	material.roughness = pow(1.0 - spec.a, 2.0);

	return material;
}
