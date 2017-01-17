engineLightStruct calculateEngineLight(vec2 rawLM) {
	engineLightStruct engine;

	engine.raw   = rawLM;
	engine.block = vec3(1.00, 0.50, 0.20) * 16.0 * (engine.raw.x / pow(16 * (1.0625 - engine.raw.x), 2.0));
	engine.sky   = vec3(0.15, 0.5, 1.0) * pow(engine.raw.y, 3.0);

	return engine;
}
