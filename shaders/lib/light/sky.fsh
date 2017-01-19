vec3 calculateSkyLight(float mask) {
	return ILLUMINANCE_SKY * vec3(0.15, 0.5, 1.0) * pow(mask, 3.0);
}
