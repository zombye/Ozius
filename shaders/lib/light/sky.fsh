vec3 calculateSkyLight(vec3 normal, vec3 upVec, float mask) {
	float skylight = mask * mask * mask;
	skylight *= 0.4 * dot(normal, upVec) + 0.5;

	return max(ILLUMINANCE_SKY * pow(skyColor, vec3(GAMMA)), 0.0175 * vec3(0.15, 0.5, 1.0)) * skylight;
}
