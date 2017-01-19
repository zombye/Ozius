vec2 calculateWind(vec3 position) {
	vec2 wind = vec2(0.0);
	vec2 pos = position.xz / textureSize(noisetex, 0);

	// Main wind
	wind = textureSmooth(noisetex, (pos / 16.0) + (frameTimeCounter * 0.01)).rg * 3.0 - 1.5;
	wind *= rainStrength + 1.0;

	// Small-scale turbulence
	const uint oct = 4;
	float ampl = 1.0 + 2.0 * rainStrength;
	float gain = 0.5 + 0.2 * rainStrength;
	float freq = 1.0;
	float lacu = 1.5;

	pos += frameTimeCounter * 0.02;
	for (uint i = 0; i < oct; i++) {
		wind += ampl * (textureSmooth(noisetex, pos * freq).rg - 0.5);
		ampl *= gain;
		freq *= lacu;
		pos  *= mat2(cos(1), sin(1), -sin(1), cos(1));
	}

	// Scale down in caves and similar
	wind *= vertexLightmap.y / 256.0;

	return wind;
}

void calculateWavingPlants(inout vec3 position, vec2 wind) {
	bool topVert = vertexUV.y < quadMidUV.y;
	if (!topVert) return;

	vec2 disp = wind * 0.1;

	position.xz += sin(disp);
	position.y  += cos(disp.x + disp.y) - 1.0;

	return;
}
void calculateWavingDoublePlants(inout vec3 position, vec2 wind) {
	bool topVert = vertexUV.y < quadMidUV.y;
	bool topHalf = vertexMetadata.z > 8;

	if (!topHalf && !topVert) return;

	vec2 disp = wind;
	disp *= mix(0.05, 0.2, float(topHalf && topVert));

	position.xz += sin(disp);
	position.y += cos((disp.x + disp.y) * mix(1.0, 0.5, float(topHalf && topVert))) - 1.0;

	return;
}
void calculateWavingLeaves(inout vec3 position, vec2 wind) {
	// TODO
	return;
}

void calculateDisplacement(inout vec3 position) {
	if (vertexLightmap.y == 0.0) return;

	vec2 wind = calculateWind(position);

	switch (int(vertexMetadata.x)) {
		case 31:  // Tall grass and fern
		case 37:  // Dandelion
		case 38:  // Flowers
		case 59:  // Wheat
		case 141: // Carrots
		case 142: // Potatoes
		case 207: // Beetroots
			calculateWavingPlants(position, wind); break;
		case 175: // Double plants
			calculateWavingDoublePlants(position, wind); break;
		case 18:  // Leaves 1
		case 161: // Leaves 2
			calculateWavingLeaves(position, wind); break;
		default: break;
	}
}
