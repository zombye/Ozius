vec2 hammersley(uint i, uint n) {
	return vec2(float(i) / float(n), float(bitfieldReverse(i)) * 2.3283064365386963e-10);
}