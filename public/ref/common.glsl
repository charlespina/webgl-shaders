#define M_PI 3.1415926535897932384626433832795

vec3 srgb_to_linear(vec3 c)
{
    return pow(c,vec3(2.2,2.2,2.2));
}

vec3 linear_to_srgb(vec3 c)
{
	return pow(c,vec3(0.4545,0.4545,0.4545));
}

vec3 fixNormalSample(vec3 v, bool flipY)
{
	vec3 res = (v - vec3(0.5,0.5,0.5))*2.0;
	res.y = flipY ? -res.y : res.y;
	return res;
}

vec3 rotate(vec3 v, float a)
{
	float angle =a*2.0*M_PI;
	float ca = cos(angle);
	float sa = sin(angle);
	return vec3(v.x*ca+v.z*sa, v.y, v.z*ca-v.x*sa);
}

