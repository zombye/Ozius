float d_GGX(float NoH, float alpha) {
	float alpha2 = alpha * alpha;
	return alpha2 / (PI * pow((NoH * NoH) * (alpha2 - 1.0) + 1.0, 2.0));
}

float g_implicit(float NoI, float NoO) {
	return NoI * NoO;
}

float f_schlick(float NoI, float NoO, float f0) {
	vec2 p = mix(pow(1.0 - saturate(vec2(NoI, NoO)), vec2(5.0)), vec2(1.0), f0);
	return p.x * p.y;
}
