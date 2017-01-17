float d_GGX(float NoH, float alpha) {
	float alpha2 = alpha * alpha;
	return alpha2 / (PI * pow((NoH * NoH) * (alpha2 - 1.0) + 1.0, 2.0));
}

float g_implicit(float NoI, float NoO) {
	return NoI * NoO;
}

float f_schlick(float NoI, float f0) {
	return mix(pow(1.0 - NoI, 5.0), 1.0, f0);
}

float f_fresnel(float cosTheta, float f0) {
	float n1 = 1.0;
	float n2 = f0ToIOR(f0);

	float p = ((n1 / n2) * sin(acos(cosTheta))); p = sqrt(1.0 - (p * p));

	float rs = ((n1 * cosTheta) - (n2 * p)) / ((n1 * cosTheta) + (n2 * p)); rs *= rs;
	float rp = ((n1 * p) - (n2 * cosTheta)) / ((n1 * p) + (n2 * cosTheta)); rp *= rp;
	return 0.5 * (rs + rp);
}
