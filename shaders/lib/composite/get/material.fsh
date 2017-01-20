materialStruct getMaterial(vec2 coord) {
	materialStruct material;

	vec4 diff = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).r));
	vec4 spec = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).g));

	material.albedo    = pow(diff.rgb, vec3(GAMMA));
	material.specular  = min(spec.r, 0.99999);
	material.metallic  = spec.g;
	material.roughness = spec.b;
	material.clearcoat = spec.a;

	return material;
}

materialStruct getMaterial(vec2 coord, out float diffalpha) {
	materialStruct material;

	vec4 diff = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).r));
	diffalpha = diff.a;
	vec4 spec = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).g));

	material.albedo    = pow(diff.rgb, vec3(GAMMA));
	material.specular  = min(spec.r, 0.99999);
	material.metallic  = spec.g;
	material.roughness = spec.b;
	material.clearcoat = spec.a;

	return material;
}
