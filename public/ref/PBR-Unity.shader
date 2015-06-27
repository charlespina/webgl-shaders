Shader "Mixamo/PBR/Unity" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_RoughMap ("Roughness", 2D) = "gray" {}
		_MetalMap ("Metallic", 2D) = "white" {}
		_NormalMap ("Normal", 2D) = "normal" {}
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;
		sampler2D _MetalMap;
		sampler2D _RoughMap;
		sampler2D _NormalMap;

		struct Input {
			float2 uv_MainTex;
		};

		fixed4 _Color;

		void surf (Input IN, inout SurfaceOutputStandard o) {
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			o.Metallic = tex2D(_MetalMap, IN.uv_MainTex).r;
			o.Smoothness = 1.0 - tex2D(_RoughMap, IN.uv_MainTex).r;
			o.Normal = UnpackNormal(tex2D (_NormalMap, IN.uv_MainTex));
			o.Alpha = c.a;
		}
		ENDCG
	} 
	FallBack "Diffuse"
}
