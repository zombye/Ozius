float diffuseOrenNayar(vec3 light, vec3 normal, vec3 view, float roughness) {
	float NoL = dot(normal, light);
	float NoV = dot(normal, view);

	vec2 angles = acos(vec2(NoL, NoV));

	// Calculate angles.x, angles.y, and gamma
	if (angles.x < angles.y) angles = angles.yx;
	float gamma = dot(view - normal * NoV, light - normal * NoL);

	float roughnessSquared = roughness * roughness;

	// These used multiple times.
	float t1 = roughnessSquared / (roughnessSquared + 0.09);
	float t2 = (2.0 / PI) * angles.y;
	float t3 = max(0.0, NoL);

	// Calculate C1, C2, and C3
	float C1 = 1.0 - 0.5 * (roughnessSquared / (roughnessSquared + 0.33));
	float C2 = 0.450 * t1;
	float C3 = (4.0 * angles.x * angles.y) / (PI * PI); C3 = 0.125 * t1 * C3 * C3;

	// Complete C2
	if(gamma >= 0.0) C2 *= sin(angles.x);
	else {
		float part = sin(angles.x) - t2;
		C2 *= part * part * part;
	}

	// Calculate P1 and P2
	float p1 = gamma * C2 * tan(angles.y);
	float p2 = (1.0 - abs(gamma)) * C3 * tan((angles.x + angles.y) / 2.0);

	// Calculate L1 and L2
	float L1 = t3 * (C1 + p1 + p2);
	float L2 = 0.17 * t3 * (roughnessSquared / (roughnessSquared + 0.13)) * (1.0 - gamma * (t2 * t2));

	return max(0.0, L1 + L2) / PI;
}
#define calculateDiffuse(x, y, z, w) diffuseOrenNayar(x, y, z, w)

#define SHADOW_SAMPLING_TYPE 1 // 0 = Single sample. 1 = 3x3 soft shadow samples. [0 1 2]

#if SHADOW_SAMPLING_TYPE == 0
vec3 sampleShadows(vec3 coord) {
	float shadow0     = textureLod(shadowtex0, coord, 0); shadow0 *= shadow0;
	float shadow1     = float(textureLod(shadowtex1, coord.xy, 0).r > coord.z);
	vec3  shadowColor = textureLod(shadowcolor0, coord.xy, 0).rgb;

	return mix(vec3(shadow0), shadowColor, shadow1 > sign(shadow0));
}
#elif SHADOW_SAMPLING_TYPE == 1
vec3 sampleShadowsSoft(vec3 coord) {
	float shadow0     = 0.0;
	float shadow1     = 0.0;
	vec3  shadowColor = vec3(0.0);

	const vec2[21] offset = vec2[21](
		              vec2(-1,  2), vec2(0,  2), vec2(1,  2),
		vec2(-2,  1), vec2(-1,  1), vec2(0,  1), vec2(1,  1), vec2(2,  1),
		vec2(-2,  0), vec2(-1,  0), vec2(0,  0), vec2(1,  0), vec2(2,  0),
		vec2(-2, -1), vec2(-1, -1), vec2(0, -1), vec2(1, -1), vec2(2, -1),
		              vec2(-1, -2), vec2(0, -2), vec2(1, -2)
	);

	for (int i = 0; i < offset.length(); i++) {
		vec3 offsCoord = coord + vec3(offset[i] / textureSize(shadowtex0, 0), 0);
		shadow0     += textureLod(shadowtex0, offsCoord, 0);
		shadow1     += float(textureLod(shadowtex1, offsCoord.xy, 0).r > offsCoord.z);
		shadowColor += textureLod(shadowcolor0, offsCoord.xy, 0).rgb;
	}
	shadow0 /= offset.length(); shadow0 *= shadow0;
	shadow1 /= offset.length();
	shadowColor /= offset.length();

	return mix(vec3(shadow0), shadowColor, shadow1 > sign(shadow0));
}
#elif SHADOW_SAMPLING_TYPE == 2
vec3 sampleShadowsPCSS(vec3 coord, float distortCoeff) {
	const float texelSize = 1.0 / textureSize(shadowtex0, 0).x;
	float pcssSpread = 0.2 / distortCoeff;

	const vec2[61] offset = vec2[61](
		                                       vec2( 4,-1), vec2( 4, 0), vec2( 4, 1),
		             vec2( 3,-3), vec2( 3,-2), vec2( 3,-1), vec2( 3, 0), vec2( 3, 1), vec2( 3, 2), vec2( 3, 3),
		             vec2( 2,-3), vec2( 2,-2), vec2( 2,-1), vec2( 2, 0), vec2( 2, 1), vec2( 2, 2), vec2( 2, 3),
		vec2( 1,-4), vec2( 1,-3), vec2( 1,-2), vec2( 1,-1), vec2( 1, 0), vec2( 1, 1), vec2( 1, 2), vec2( 1, 3), vec2( 1, 4),
		vec2( 0,-4), vec2( 0,-3), vec2( 0,-2), vec2( 0,-1), vec2( 0, 0), vec2( 0, 1), vec2( 0, 2), vec2( 0, 3), vec2( 0, 4),
		vec2(-1,-4), vec2(-1,-3), vec2(-1,-2), vec2(-1,-1), vec2(-1, 0), vec2(-1, 1), vec2(-1, 2), vec2(-1, 3), vec2(-1, 4),
		             vec2(-2,-3), vec2(-2,-2), vec2(-2,-1), vec2(-2, 0), vec2(-2, 1), vec2(-2, 2), vec2(-2, 3),
		             vec2(-3,-3), vec2(-3,-2), vec2(-3,-1), vec2(-3, 0), vec2(-3, 1), vec2(-3, 2), vec2(-3, 3),
		                                       vec2(-4,-1), vec2(-4, 0), vec2(-4, 1)
	);

	float depthAverage = 0.0;
	for (int i = 0; i < offset.length(); i++) {
		vec4 depthSamples = textureGather(shadowtex1, coord.xy + (offset[i] * texelSize * 3 / distortCoeff));
		depthAverage += sumof(max(vec4(0.0), coord.z - depthSamples));
	}
	depthAverage /= offset.length();

	float penumbraSize = max(depthAverage * pcssSpread, texelSize.x);

	float shadow0     = 0.0;
	float shadow1     = 0.0;
	vec3  shadowColor = vec3(0.0);
	for (int i = 0; i < offset.length(); i++) {
		vec3 sampleCoord = vec3(coord.xy + (offset[i] * penumbraSize * 0.25), coord.p);

		shadow0     += textureLod(shadowtex0, sampleCoord, penumbraSize);
		shadow1     += float(textureLod(shadowtex1, sampleCoord.xy, penumbraSize).r > coord.z);
		shadowColor += textureLod(shadowcolor0, sampleCoord.xy, penumbraSize).rgb;
	}
	shadow0 /= offset.length(); shadow0 *= shadow0;
	shadow1 /= offset.length();
	shadowColor /= offset.length();

	return mix(vec3(shadow0), shadowColor, shadow1 > sign(shadow0));
}
#endif

vec3 calculateShadows(vec3 positionLocal, vec3 normal) {
	vec3 shadowCoord = (shadowProjection * shadowModelView * vec4(positionLocal, 1.0)).xyz;

	float distortCoeff = 1.0 + length(shadowCoord.xy);

	float zBias = ((2.0 / shadowProjection[0].x) / textureSize(shadowtex1, 0).x) * shadowProjection[2].z;
	zBias *= tan(acos(abs(dot(normalize(shadowLightPosition), normal))));
	zBias *= mix(1.0, SQRT2, abs(shadowAngle - 0.25) * 4.0);

	#if SHADOW_SAMPLING_TYPE == 1
	zBias *= 2.5;
	#endif

	zBias *= distortCoeff * distortCoeff;
	zBias -= (0.0059 * shadowProjection[0].x) * SQRT2;

	shadowCoord.z += zBias;

	shadowCoord.xy /= distortCoeff;
	shadowCoord.z *= 0.25;

	shadowCoord = shadowCoord * 0.5 + 0.5;

	#if SHADOW_SAMPLING_TYPE == 0
	return sampleShadows(shadowCoord);
	#elif SHADOW_SAMPLING_TYPE == 1
	return sampleShadowsSoft(shadowCoord);
	#elif SHADOW_SAMPLING_TYPE == 2
	return sampleShadowsPCSS(shadowCoord, distortCoeff);
	#endif
}

vec3 calculateGlobalLight(surfaceStruct surface) {
	float diffuse = calculateDiffuse(normalize(shadowLightPosition), surface.normal, normalize(-surface.positionView), surface.material.roughness);
	vec3 shadows = calculateShadows(surface.positionLocal, surface.normalGeom);

	vec3 sunlightColor = mix(vec3(1.0, 0.6, 0.2) * 0.4, vec3(1.0, 0.96, 0.95), 1.0 - saturate(distance(mod(globalTime, 12e2), 300.0) / 300.0));

	vec3 light = mix(0.2 * vec3(1.0, 0.9, 0.85), ILLUMINANCE_SUN * sunlightColor, mod(globalTime, 12e2) < 600.0);
	light *= diffuse * shadows;

	return light;
}
