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

#define SHADOW_SAMPLING_TYPE 1 // 0 = Single sample. 1 = 12-sample soft shadows. [0 1]

#if SHADOW_SAMPLING_TYPE == 0
float sampleShadows(vec3 coord) {
	float shadow = texture(shadowtex1, coord);

	return shadow * shadow;
}
#elif SHADOW_SAMPLING_TYPE == 1
float sampleShadowsSoft(vec3 coord) {
	const vec2[12] offset = vec2[12](
		                 vec2(-0.5, 1.5), vec2( 0.5, 1.5),
		vec2(-1.5, 0.5), vec2(-0.5, 0.5), vec2( 0.5, 0.5), vec2( 1.5, 0.5),
		vec2(-1.5,-0.5), vec2(-0.5,-0.5), vec2( 0.5,-0.5), vec2( 1.5,-0.5),
		                 vec2(-0.5,-1.5), vec2( 0.5,-1.5)
	);
	vec2 resolution = textureSize(shadowtex1, 0);

	float shadow = 0.0;
	for (int i = 0; i < offset.length(); i++) {
		shadow += texture(shadowtex1, coord + vec3(offset[i] / resolution, 0));
	}
	shadow /= offset.length(); shadow *= shadow;

	return shadow;
}
#endif

#ifdef HSSRS
float calculateHSSRS(vec3 viewSpace, vec3 lightVector) {
	vec3 increment = lightVector * HSSRS_RAY_LENGTH / HSSRS_RAY_STEPS;

	for (uint i = 0; i < HSSRS_RAY_STEPS; i++) {
		viewSpace += increment;

		vec3 screenSpace = viewSpaceToScreenSpace(viewSpace);
		if (any(greaterThan(abs(screenSpace - 0.5), vec3(0.5)))) return 1.0;

		float diff = viewSpace.z - linearizeDepth(texture(depthtex1, screenSpace.xy).r);
		if (diff < 0.005 * viewSpace.z && diff > 0.05 * viewSpace.z) return i / HSSRS_RAY_STEPS;
	}

	return 1.0;
}
#endif

float calculateShadows(
	vec3 positionLocal,
	#ifdef HSSRS
	vec3 positionView,
	bool translucent,
	#endif
	vec3 normal
) {
	vec3 shadowCoord = (shadowProjection * shadowModelView * vec4(positionLocal, 1.0)).xyz;

	float distortCoeff = 1.0 + length(shadowCoord.xy);

	#ifdef HSSRS
	if (calculateHSSRS(positionView, world.globalLightVector * distortCoeff) < 1.0 && !translucent) return 0.0;
	shadowCoord.z += HSSRS_RAY_LENGTH * shadowProjection[2].z * distortCoeff;
	shadowCoord.z += 0.0002;
	#else
	float zBias = ((2.0 / shadowProjection[0].x) / textureSize(shadowtex1, 0).x) * shadowProjection[2].z;
	zBias *= min(tan(acos(abs(dot(world.globalLightVector, normal)))), 5.0);
	zBias *= mix(1.0, SQRT2, abs(shadowAngle - 0.25) * 4.0);

	#if SHADOW_SAMPLING_TYPE == 1
	zBias *= 2.5;
	#endif

	zBias *= distortCoeff * distortCoeff;
	zBias -= (0.0059 * shadowProjection[0].x) * SQRT2;

	shadowCoord.z += zBias;
	#endif

	shadowCoord.xy /= distortCoeff;
	shadowCoord.z *= 0.25;

	shadowCoord = shadowCoord * 0.5 + 0.5;

	#if SHADOW_SAMPLING_TYPE == 0
	return sampleShadows(shadowCoord);
	#elif SHADOW_SAMPLING_TYPE == 1
	return sampleShadowsSoft(shadowCoord);
	#endif
}

#ifdef GI
vec3 getGI(vec2 coord) {
	return texture(colortex4, coord * GI_RESOLUTION).rgb;
}
#endif

vec3 calculateGlobalLight(
	worldStruct world,
	surfaceStruct surface
	#ifdef COMPOSITE
	, float shadows
	#endif
) {
	bool translucent =
	   surface.mat.id == 18
	|| surface.mat.id == 30
	|| surface.mat.id == 31
	|| surface.mat.id == 37
	|| surface.mat.id == 38
	|| surface.mat.id == 59
	|| surface.mat.id == 83
	|| surface.mat.id == 106
	|| surface.mat.id == 111
	|| surface.mat.id == 141
	|| surface.mat.id == 142
	|| surface.mat.id == 161
	|| surface.mat.id == 175
	|| surface.mat.id == 207;

	vec3 diffuse;
	if (translucent) {
		float NoL = dot(surface.normal, world.globalLightVector);

		// Not realistic but looks good.
		diffuse = mix(surface.mat.diffuse * 0.65 + 0.35, vec3(1.0), NoL * 0.5 + 0.5) * (abs(NoL) * 0.5 + 0.5) / PI;
	} else diffuse = vec3(calculateDiffuse(world.globalLightVector, surface.normal, normalize(-surface.positionView), surface.mat.roughness));

	#ifndef COMPOSITE
	float shadows = 0.0;
	#endif
	if (any(greaterThan(diffuse, vec3(0.0)))) {
		shadows = calculateShadows(
			surface.positionLocal,
			#ifdef HSSRS
			surface.positionView,
			translucent,
			#endif
			surface.normalGeom
		);
	}

	vec3 light = world.globalLightColor * diffuse * shadows;

	#ifdef GI
	light += world.globalLightColor * getGI(surface.positionScreen.xy);
	#endif

	return light;
}
