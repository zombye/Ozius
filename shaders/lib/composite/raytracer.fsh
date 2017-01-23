bool raytraceIntersection(vec3 pos, vec3 vec, out vec3 screenSpace, out vec3 viewSpace) {
	const float maxSteps  = 32;
	const float maxRefs   = 2;
	const float stepSize  = 0.5;
	const float stepScale = 1.6;

	vec3 increment = vec * stepSize;

	viewSpace = pos + increment;

	uint refinements = 0;

	for (uint i = 0; i < maxSteps; i++) {
		viewSpace  += increment;
		screenSpace = viewSpaceToScreenSpace(viewSpace);

		if (any(greaterThan(abs(screenSpace - 0.5), vec3(0.5)))) return false;

		float screenZ = texture(depthtex1, screenSpace.xy).r;
		float diff    = viewSpace.z - linearizeDepth(screenZ);

		if (diff <= 0.0) {
			//--// Do refinements, mainly for stuff that's far away.
			if (refinements < maxRefs) {
				viewSpace -= increment;
				increment *= 0.1;
				refinements++;

				continue;
			}

			//--// Refinements are done, so now intersect a plane to get an accurate reflection. Mainly for nearby stuff.

			vec3 sampleNorm = getNormalGeom(screenSpace.xy);

			// We don't want to reflect something that we had to go trough an opaque object to reach
			if (0 < dot(sampleNorm, vec)) return false;

			vec3 samplePos  = screenSpaceToViewSpace(vec3(screenSpace.xy, screenZ));

			// Accurately intersect the plane we think is the right one
			viewSpace  += vec * (dot(samplePos - viewSpace, sampleNorm) / dot(vec, sampleNorm));
			screenSpace = viewSpaceToScreenSpace(viewSpace);

			// Check to make sure we've actually hit something (or got close)
			screenZ = texture(depthtex1, screenSpace.xy).r;
			if (any(greaterThan(abs(screenSpace - 0.5), vec3(0.5))) || abs(screenZ - screenSpace.z) > 0.001 || screenZ == 1.0) return false;

			return true;
		}

		increment *= stepScale;
	}

	return false;
}
