struct material {
	vec3 diffuse;
	vec3 specular;
	vec3 emission;

	float roughness;
};
const material emptyMaterial = {
	vec3(0.8),
	vec3(0.0),
	vec3(0.0),
	0.0
};

// Gets a material that has been packed into a single RG32F sampler.
material getPackedMaterial(sampler2D pack, vec2 coord) {
	material upm = emptyMaterial;

	vec4 diff = unpackUnorm4x8(floatBitsToUint(texelFetch(pack, ivec2(coord * textureSize(pack, 0)), 0).r));
	vec4 spec = unpackUnorm4x8(floatBitsToUint(texelFetch(pack, ivec2(coord * textureSize(pack, 0)), 0).g));

	upm.diffuse   = pow(diff.rgb, vec3(GAMMA));
	upm.specular  = vec3(min(spec.r, 0.999));
	upm.emission  = vec3(0.0);
	upm.roughness = 1.0 - spec.b; upm.roughness *= upm.roughness;

	return upm;
}
// Gets a material.
material getMaterial(sampler2D diffuse, sampler2D specular, vec2 coord) {
	material m = emptyMaterial;

	vec4 diff = texture(diffuse,  coord);
	vec4 spec = texture(specular, coord);

	m.diffuse   = pow(diff.rgb, vec3(GAMMA));
	m.specular  = vec3(min(spec.r, 0.999));
	m.emission  = vec3(1.0 - spec.a);
	m.roughness = 1.0 - spec.b; m.roughness *= m.roughness;

	return m;
}
