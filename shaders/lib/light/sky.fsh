vec3 calculateSkyLight(float mask) {
	return mix(ILLUMINANCE_SKY * 2.5e-5, ILLUMINANCE_SKY, sunAngle < 0.5) * pow(skyColor, vec3(GAMMA)) * pow(mask, 3.0);
}
