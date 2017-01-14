float calculateShadow(vec3 positionLocal, vec3 normal) {
	vec3 shadowCoord = (shadowProjection * shadowModelView * vec4(positionLocal, 1.0)).xyz;

	float distortCoeff = 1.0 + length(shadowCoord.xy);

	float zBias = ((2.0 / shadowProjection[0].x) / textureSize(shadowtex0, 0).x) * shadowProjection[2].z;
	zBias *= tan(acos(abs(dot(normalize(shadowLightPosition), normal))));
	zBias *= distortCoeff * distortCoeff;
	zBias *= mix(1.0, SQRT2, abs(shadowAngle - 0.25) * 4.0);
	zBias -= (0.0059 * shadowProjection[0].x) * SQRT2;

	shadowCoord.z += zBias;

	shadowCoord.xy /= distortCoeff;
	shadowCoord.z *= 0.25;

	shadowCoord = shadowCoord * 0.5 + 0.5;

	float shadow = texture(shadowtex0, shadowCoord);

	return shadow * shadow;
}