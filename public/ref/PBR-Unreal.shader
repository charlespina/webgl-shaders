Shader "Mixamo/PBR/Unreal" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("BaseColor (RGBA)", 2D) = "white" {}
		[Gamma] _RoughMap ("Roughness", 2D) = "white" {}
		_MetalMap ("Metallic", 2D) = "black"
		_NormalMap ("Normal", 2D) = "normal" {}
		_Roughness ("Roughness Coefficient", Range(0.0, 2.0)) = 1.0
		_SpecularAmount ("Specular Amount", Float) = 1.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Unreal fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0
		
		#include "FuseLighting.cginc"
		
		fixed4 _Color;
		sampler2D _MainTex;
		sampler2D _RoughMap;
		sampler2D _MetalMap;
		sampler2D _NormalMap;
		float _Roughness;
		float _SpecularAmount;

		struct Input {
			float2 uv_MainTex;
		};


		void surf (Input IN, inout PbrOutput o) {
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Normal = UnpackNormal(tex2D (_NormalMap, IN.uv_MainTex));
			o.Roughness = _Roughness * tex2D (_RoughMap, IN.uv_MainTex).r;
			o.Metallic = tex2D (_MetalMap, IN.uv_MainTex).r;
			o.Alpha = c.a;
		}
		
		ENDCG
	} 
	FallBack "Diffuse"
}
