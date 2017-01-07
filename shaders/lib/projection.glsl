vec2 equirectangleForward(vec3 vec) {
	return vec2(atan(vec.x, vec.y), asin(vec.z)) / vec2(TAU, PI) + 0.5;
}
vec3 equirectangleReverse(vec2 coord) {
	coord = (coord - 0.5) * vec2(TAU, PI);

	float cosLat = cos(coord.y);

	return normalize(vec3(cosLat * sin(coord.x), cosLat * cos(coord.x), sin(coord.y)));
}
