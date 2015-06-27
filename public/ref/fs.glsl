//////////////////////////////// Fragment shader
#version 120
#extension GL_ARB_shader_texture_lod : require

#include "../common/common.glsl"
#include "../common/parallax.glsl"

varying vec3 iFS_Normal;
varying vec2 iFS_UV;
varying vec3 iFS_Tangent;
varying vec3 iFS_Binormal;
varying vec3 iFS_PointWS;

uniform vec3 Lamp0Pos = vec3(0.0,0.0,70.0);
uniform vec3 Lamp0Color = vec3(1.0,1.0,1.0);
uniform float Lamp0Intensity = 1.0;
uniform vec3 Lamp1Pos = vec3(70.0,0.0,0.0);
uniform vec3 Lamp1Color = vec3(0.198,0.198,0.198);
uniform float Lamp1Intensity = 1.0;

uniform float AmbiIntensity = 1.0;
uniform float EmissiveIntensity = 1.0;

uniform float tiling = 1.0;
uniform float envRotation = 0.0;
uniform float Depth = 0.0;
uniform bool flipY = true;
uniform bool sRGBBaseColor = true;

uniform sampler2D heightMap;
uniform sampler2D normalMap;
uniform sampler2D baseColorMap;
uniform sampler2D metallicMap;
uniform sampler2D roughnessMap;
uniform sampler2D aoMap;
uniform sampler2D emissiveMap;
uniform sampler2D environmentMap;
uniform sampler2D specularLevel;

uniform mat4 viewInverseMatrix;

// Number of miplevels in the envmap
uniform float maxLod = 12.0;

// Sample Pos table
uniform sampler2D vanDerCorputMap;
// Sample table Texture Width
// See cTextureWidth contant in samplespostableloader.cpp
const int vanDerCorputMapWidth = 256;
const int vanDerCorputMapHeight = 4;

// Actual number of samples in the table
uniform int nbSamples = 16;

// Irradiance spherical harmonics polynomial coefficients
// This is a color 2nd degree polynomial in (x,y,z), so it needs 10 coefficients
// for each color channel
uniform vec3 shCoefs[10];

// This must be included after the declaration of the uniform arrays since they
// can't be passed as functions parameters for performance reasons (on macs)
#include "../common/pbr_ibl.glsl"

float fit_roughness(float r)
{
// Fit roughness values to a more usable curve
	return r;
}

void main()
{
	vec3 cameraPosWS = viewInverseMatrix[3].xyz;
	vec3 pointToLight0DirWS = normalize(Lamp0Pos - iFS_PointWS);
	vec3 pointToLight1DirWS = normalize(Lamp1Pos - iFS_PointWS);
	vec3 pointToCameraDirWS = normalize(cameraPosWS - iFS_PointWS);

	// ------------------------------------------
	// Parallax
	vec2 uv = updateUV(
		heightMap,
		pointToCameraDirWS,
		iFS_Normal, iFS_Tangent, iFS_Binormal,
		Depth,
		iFS_UV,
		tiling);

	// ------------------------------------------
	// Add Normal from normalMap
	vec3 fixedNormalOS = iFS_Normal;  // HACK for empty normal textures
	vec3 normalTS = texture2D(normalMap,uv).xyz;
	if(length(normalTS)>0.0001)
	{
		normalTS = fixNormalSample(normalTS,flipY);
		fixedNormalOS = normalize(
			normalTS.x*iFS_Tangent +
			normalTS.y*iFS_Binormal +
			normalTS.z*iFS_Normal );
	}

	vec3 fixedNormalWS = fixedNormalOS;

	// ------------------------------------------
	// Compute material model (diffuse, specular & roughness)
	float dielectricSpec = 0.08 * texture2D(specularLevel,uv).r;
	vec3 dielectricColor = vec3(dielectricSpec, dielectricSpec, dielectricSpec);
	const float minRoughness=1e-4;
	// Convert the base color from sRGB to linear (we should have done this when
	// loading the texture but there is no way to specify which colorspace is
	// uѕed for a given texture in Designer yet)
	vec3 baseColor = sRGBBaseColor ?
		srgb_to_linear(texture2D(baseColorMap,uv).rgb) :
		texture2D(baseColorMap,uv).rgb;
	float metallic = texture2D(metallicMap,uv).r;
	float roughness = max(minRoughness, fit_roughness(texture2D(roughnessMap,uv).r));

	vec3 diffColor = baseColor * (1.0 - metallic);
	vec3 specColor = mix(dielectricColor, baseColor, metallic);

	// ------------------------------------------
	// Compute point lights contributions
	vec3 contrib0 = pointLightContribution(
			fixedNormalWS,
			pointToLight0DirWS,
			pointToCameraDirWS,
			diffColor,
			specColor,
			roughness,
			Lamp0Color,
			Lamp0Intensity );
	vec3 contrib1 = pointLightContribution(
			fixedNormalWS,
			pointToLight1DirWS,
			pointToCameraDirWS,
			diffColor,
			specColor,
			roughness,
			Lamp1Color,
			Lamp1Intensity );

	// ------------------------------------------
	// Image based lighting contribution
	vec3 contribE = computeIBL(
		environmentMap, envRotation, maxLod,
		vanDerCorputMap, vanDerCorputMapWidth, vanDerCorputMapHeight, nbSamples,
		fixedNormalWS, iFS_Tangent, iFS_Binormal,
		pointToCameraDirWS,
		diffColor, specColor, roughness,
		AmbiIntensity * texture2D(aoMap,uv).r );

	// ------------------------------------------
	//Emissive
	vec3 emissiveContrib = srgb_to_linear(texture2D(emissiveMap,uv).rgb) * EmissiveIntensity;

	// ------------------------------------------
	vec3 finalColor = contrib0 + contrib1 + contribE + emissiveContrib;

	// Final Color
	// Convert the fragment color from linear to sRGB for display (we should
	// make the framebuffer use sRGB instead).
	gl_FragColor = vec4(linear_to_srgb(finalColor), 1.0);
}

