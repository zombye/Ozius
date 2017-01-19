vec3 skyAtmosphere(vec3 viewVec, vec3 sunVec) {
	float VoL = dot(viewVec, sunVec);
	float VoU = dot(viewVec, vec3(0.0, 0.0, 1.0));

	float mie      = 0.03 * miePhase(VoL);
	vec3  rayleigh = vec3(0.15, 0.5, 1.0) * rayleighPhase(VoL);
	return (rayleigh + mie) * atmosphereRelAM(VoU) * 0.5;
}
