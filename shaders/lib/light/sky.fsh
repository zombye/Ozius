vec3 calculateSkyLight(float mask) {
	return max(ILLUMINANCE_SKY * pow(skyColor, vec3(GAMMA)), 0.02 * vec3(0.15, 0.5, 1.0)) * pow(mask, 3.0);
}
