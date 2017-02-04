vec3 calculateSkyLight(float mask) {
	return mix(ILLUMINANCE_SKY * 2.5e-5, ILLUMINANCE_SKY, sunAngle < 0.5) * vec3(0.15, 0.5, 1.0) * pow(mask, 3.0);
}
