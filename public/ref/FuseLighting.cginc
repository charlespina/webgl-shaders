#include "UnityShaderVariables.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityLightingCommon.cginc"
#include "UnityGlobalIllumination.cginc"

struct PbrOutput
{
    fixed3 Albedo;      // base (diffuse or specular) color
    fixed3 Normal;      // tangent space normal, if written
    half3 Emission;
    half Metallic;      // 0=non-metal, 1=metal
    half Roughness;    // 0=smooth, 1=rough
    half Occlusion;     // occlusion (default 1)
    fixed Alpha;        // alpha for transparencies
};

inline float Chi(fixed x)
{
	return x > 0.0 ? 1.0 : 0.0;
}

inline float SchlickFresnel(fixed VdH, fixed3 F0)
{
	return F0 + (1.0-F0) * pow(1.0-VdH, 5.0);
}

inline float UnrealFresnel(fixed VdH, fixed F0)
{
	return F0 + (1-F0)*pow(2.0, (-5.55473*VdH-6.98316)*VdH);
}

inline float GeometryTerm(fixed NdV, fixed Roughness)
{
	float k = pow(Roughness+1.0, 2.0);
	return NdV/((NdV)*(1.0-k)+k);
}

inline float DistributionTerm(fixed NdH, float alpha2)
{
	float Dden = 3.14159*((NdH*NdH)*(alpha2-1.0)+1.0);
	return alpha2/(Dden*Dden);
}

// http://www.codinglabs.net/article_physically_based_rendering_cook_torrance.aspx
inline float GeometryTermAlt(fixed3 V, fixed3 N, fixed3 H, fixed alpha)
{
	float VdH = saturate(dot(V, H));
	float VdH2 = VdH*VdH;
	float x = Chi(VdH/saturate(dot(V,N)));
	float tan2 = (1.0-VdH2)/VdH2;
	return (x*2.0)/(1.0+sqrt(1.0+alpha*alpha*tan2));
}

inline float DistributionTermAlt(fixed NdH, float alpha2)
{
	float NdH2 = NdH*NdH;
	float Dden = (NdH2*alpha2)+(1-NdH2);
	return (Chi(NdH)*alpha2)/(3.141592653*Dden*Dden);
}

inline half4 LightingFuse (PbrOutput s, fixed3 lightDir, fixed3 viewDir, fixed atten)
{
	float3 L = normalize(lightDir);
	float3 V = normalize(viewDir);
	float3 H = normalize(V+L);
	float NdL = saturate(dot(s.Normal, L));
	float NdH = saturate(dot(s.Normal, H));
	float VdH = saturate(dot(V, H));
	float NdV = saturate(dot(s.Normal, V));
	float alpha = acos(NdH);

	//G (geo)
	float G = min(1.0, min(2.0*NdH*NdV/VdH, 2.0*NdH*NdL/VdH)); //geometric attenuation factor
	
	//F (fresnel)
	float F0 = lerp(0.04, 0.08, s.Metallic); // reflection at normal incidence 
	float F = pow(1.0 - VdH, 5.0) * (1.0 - F0) + F0;
	
	//D (roughness)
	float m = s.Roughness; // roughness
	float D = 1.0 * exp(-(alpha)/(m*m));
	
	float spec = F*D*G*(1.0 - NdV);
	 
	//float DFG = (D * F * G) * (1.0 - NdV);
	//spec = spec_color * DFG * specular_constant;
	half4 c;
	c.rgb = _LightColor0.rgb * NdL; 
	
	c.a = s.Alpha;
	return c;
}

inline half4 LightingAlt (PbrOutput s, fixed3 lightDir, fixed3 viewDir, fixed atten)
{
	float3 L = normalize(lightDir);
	float3 V = normalize(viewDir);
	float3 H = normalize(V+L);
	float VdH = saturate(dot(V, H));
	float NdH = saturate(dot(s.Normal, H));
	float NdL = saturate(dot(s.Normal, L));
	float NdV = saturate(dot(s.Normal, V));

	float alpha = s.Roughness * s.Roughness;
	float alpha2 = alpha*alpha;

	float ior = 1.44;
	float3 F0 = abs((1.0-ior)/(1.0+ior)); 
	F0 = F0*F0;
	F0 = lerp(F0, s.Albedo, s.Metallic);
	float D = DistributionTermAlt(NdH, alpha2);
	float Gv = GeometryTermAlt(V, s.Normal, H, alpha);
	float Gl = GeometryTermAlt(L, s.Normal, H, alpha);
	float F = SchlickFresnel(VdH, F0);
	float sinT = sqrt(1.0-NdL*NdL); 
	float spec = (F*D*Gv*Gl*sinT)/(saturate(4.0*(dot(s.Normal, L))*(dot(s.Normal, V))) +0.05);


	// when completely smooth, all light is reflected
	// when metallic, diffuse contribution is nil
	float diff = (s.Roughness)*(1.0-s.Metallic)*NdL;
	
	half4 c;
	c.rgb = _LightColor0.rgb * (diff*s.Albedo + spec * lerp(fixed3(1.0,1.0,1.0), s.Albedo, s.Metallic)) * atten;
	c.a = 1.0;
	return c;
}

		
inline half4 LightingUnreal (PbrOutput s, fixed3 lightDir, fixed3 viewDir, fixed atten)
{
	float3 L = normalize(lightDir);
	float3 V = normalize(viewDir);
	float3 H = normalize(V+L);
	float VdH = saturate(dot(V, H));
	float NdH = saturate(dot(s.Normal, H));
	float NdL = saturate(dot(s.Normal, L));
	float NdV = saturate(dot(s.Normal, V));

	float alpha = s.Roughness * s.Roughness;
	float alpha2 = alpha*alpha;

	float F0 = lerp(0.04, s.Albedo, s.Metallic);
	float D = DistributionTerm(NdH, alpha2);
	float Gv = GeometryTerm(NdV, s.Roughness);
	float Gl = GeometryTerm(NdL, s.Roughness);
	float F = UnrealFresnel(VdH, F0);
	float spec = (F*Gl*Gv*D)/(4.0*dot(s.Normal, L)*dot(s.Normal, V));			

	// when completely smooth, all light is reflected
	// when metallic, diffuse contribution is nil
	float diff = (s.Roughness)*(1.0-s.Metallic)*NdL;
	
	half4 c;
	c.rgb = _LightColor0.rgb * (diff*s.Albedo + spec * lerp(fixed3(1.0,1.0,1.0), s.Albedo, s.Metallic)) * atten;
	c.a = 1.0;
	return c;
}


