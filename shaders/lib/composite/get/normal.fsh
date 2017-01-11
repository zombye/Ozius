#define getNormal(coord)     unpackNormal(textureRaw(colortex1, coord).r)
#define getNormalGeom(coord) unpackNormal(textureRaw(colortex1, coord).g)
