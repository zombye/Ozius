bool raytraceIntersection(vec3 pos, vec3 vec, out vec3 screenSpace, out vec3 viewSpace) {
	const float maxSteps  = 32;
	const float stepSize  = 0.5;
	const float stepScale = 1.6;

	vec3 increment = vec * stepSize;

	viewSpace = pos + increment;

	for (uint i = 0; i < maxSteps; i++) {
		viewSpace  += increment;
		screenSpace = viewSpaceToScreenSpace(viewSpace);

		if (any(greaterThan(abs(screenSpace - 0.5), vec3(0.5)))) return false;

		float screenZ = texture(depthtex1, screenSpace.xy).r;
		float diff    = viewSpace.z - linearizeDepth(screenZ);

		if (diff <= 0.0) {
			// Get the info required to accurately intersect a plane
			vec3 samplePos  = screenSpaceToViewSpace(vec3(screenSpace.xy, screenZ));
			vec3 sampleNorm = getNormalGeom(screenSpace.xy);

			// Accurately intersect the plane we think is the right one
			viewSpace  += vec * (dot(samplePos - viewSpace, sampleNorm) / dot(vec, sampleNorm));
			screenSpace = viewSpaceToScreenSpace(viewSpace);

			// Check to make sure we've actually hit something
			// TODO: Also check to make sure we at least got close enough that it's still believable that we actually hit the plane we think we hit.
			if (any(greaterThan(abs(screenSpace - 0.5), vec3(0.5))) || texture(depthtex1, screenSpace.xy).r == 1.0) return false;

			return true;
		}

		increment *= stepScale;
	}

	return false;
}
