materialStruct getMaterial(vec2 coord) {
	materialStruct material;

	vec4 diff = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).r));
	vec4 spec = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).g));
	vec4 data = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).b));

	material.albedo    = diff.rgb;
	material.specular  = spec.r;
	material.metallic  = spec.g;
	material.roughness = spec.b;
	material.clearcoat = spec.a;
	material.dR        = data.r;
	material.dG        = data.g;
	material.dB        = data.b;
	material.dA        = data.a;

	return material;
}

materialStruct getMaterial(vec2 coord, out float diffalpha) {
	materialStruct material;

	vec4 diff = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).r));
	diffalpha = diff.a;
	vec4 spec = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).g));
	vec4 data = unpackUnorm4x8(floatBitsToUint(textureRaw(colortex0, coord).b));

	material.albedo    = pow(diff.rgb, vec3(2.2));
	material.specular  = spec.r;
	material.metallic  = spec.g;
	material.roughness = spec.b;
	material.clearcoat = spec.a;
	material.dR        = data.r;
	material.dG        = data.g;
	material.dB        = data.b;
	material.dA        = data.a;

	return material;
}
