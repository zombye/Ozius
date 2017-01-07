float d_GGX(float NoH, float alpha) {
	float alpha2 = alpha * alpha;
	return alpha2 / (PI * pow((NoH * NoH) * (alpha2 - 1.0) + 1.0, 2.0));
}

float g_implicit(float NoI, float NoO) {
	return NoI * NoO;
}

float f_schlick(float NoI, float R0) {
	return mix(pow(1.0 - NoI, 5.0), 1.0, R0);
}
