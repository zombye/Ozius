vec3 calculateSky(vec2 coord) {
	vec3 dir = equirectangleReverse(coord);

	vec3 sky = skyAtmosphere(dir, normalize(mat3(gbufferModelViewInverse) * shadowLightPosition).xzy);

	return sky * ILLUMINANCE_SKY;
}
