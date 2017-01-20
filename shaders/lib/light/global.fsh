
float diffuseLambert(float NoI) {
	return NoI / PI;
}

float calculateShadows(vec3 positionLocal, vec3 normal) {
	vec3 shadowCoord = (shadowProjection * shadowModelView * vec4(positionLocal, 1.0)).xyz;

	float distortCoeff = 1.0 + length(shadowCoord.xy);

	float zBias = ((2.0 / shadowProjection[0].x) / textureSize(shadowtex0, 0).x) * shadowProjection[2].z;
	zBias *= tan(acos(abs(dot(normalize(shadowLightPosition), normal))));
	zBias *= mix(1.0, SQRT2, abs(shadowAngle - 0.25) * 4.0);

	zBias *= distortCoeff * distortCoeff;
	zBias -= (0.0059 * shadowProjection[0].x) * SQRT2;

	shadowCoord.z += zBias;

	shadowCoord.xy /= distortCoeff;
	shadowCoord.z *= 0.25;

	shadowCoord = shadowCoord * 0.5 + 0.5;

	float shadow = texture(shadowtex0, shadowCoord);

	return shadow * shadow;
}

vec3 calculateGlobalLight(surfaceStruct surface) {
	float diffuse = max(dot(surface.normal, normalize(shadowLightPosition)), 0.0) / PI;
	float shadows = calculateShadows(surface.positionLocal, surface.normalGeom);

	vec3 sunlightColor = mix(vec3(1.0, 0.6, 0.2) * 0.4, vec3(1.0, 0.96, 0.95), 1.0 - saturate(distance(mod(globalTime, 12e2), 300.0) / 300.0));

	vec3 light = mix(0.2 * vec3(1.0, 0.9, 0.85), ILLUMINANCE_SUN * sunlightColor, mod(globalTime, 12e2) < 600.0);
	light *= diffuse * shadows;

	return light;
}
