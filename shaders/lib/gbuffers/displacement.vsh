vec2 calculateWind(vec3 position) {
	vec2 wind = vec2(0.0);
	vec2 pos = (position.xz / 64.0) + frameTimeCounter * 0.02;
	float scale = 1.0;

	// Main wind
	wind = textureSmooth(noisetex, (pos / 15.0) + (frameTimeCounter * 0.02)).rg * 4.0 - 2.0;

	// Small-scale turbulence
	const int oct = 4;
	for (int i = 0; i < oct; i++) {
		wind += scale * (textureSmooth(noisetex, pos + (frameTimeCounter * 0.02)).rg * 2.0 - 1.0);
		pos = (pos + (wind * 0.002)) * 1.5;
		scale *= 0.5;
	}

	// Scale down in caves and similar
	wind *= vertexLightmap.y / 256.0;

	return wind;
}

void calculateWavingPlants(inout vec3 position, vec2 wind, bool topVert) {
	if (!topVert) return;

	vec2 disp = wind * 0.1;

	position.xz += sin(disp);
	position.y  += cos(disp.x + disp.y) - 1.0;

	return;
}
void calculateWavingDoublePlants(inout vec3 position, vec2 wind, bool topVert) {
	// TODO
	return;
}
void calculateWavingLeaves(inout vec3 position, vec2 wind) {
	// TODO
	return;
}

void calculateDisplacement(inout vec3 position) {
	if (vertexLightmap.y == 0.0) return;

	vec2 wind = calculateWind(position);
	bool topVert = vertexUV.y < quadMidUV.y;

	switch (int(vertexMetadata.x)) {
		case 31:  // Tall grass and fern
		case 37:  // Dandelion
		case 38:  // Flowers
		case 59:  // Wheat
		case 141: // Carrots
		case 142: // Potatoes
		case 207: // Beetroots
			calculateWavingPlants(position, wind, topVert);
		case 175: // Double plants
			calculateWavingDoublePlants(position, wind, topVert);
		case 18:  // Leaves 1
		case 161: // Leaves 2
			calculateWavingLeaves(position, wind); break;
		default: break;
	}
}
