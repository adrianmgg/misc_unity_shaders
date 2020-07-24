Shader "Custom/OrderedDithering" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM

		#include "util/map_range.cginc"
		
		#pragma surface surf Standard fullforwardshadows finalcolor:finalColor

		#pragma target 3.0

		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
			float4 screenPos;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		void surf (Input IN, inout SurfaceOutputStandard o) {
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}

		static const uint4x4 thresholdMap = uint4x4(
			0,  8,  2,  10,
			12, 4,  14, 6,
			3,  11, 1,  9,
			15, 7,  13, 5
		);

		void finalColor(Input IN, SurfaceOutputStandard o, inout fixed4 color) {
			uint2 pixelPos = map(IN.screenPos.xy/IN.screenPos.w, 0, 1, 0, _ScreenParams.xy);
			uint2 thresholdMapPos = pixelPos % 4;
			uint threshold = thresholdMap[thresholdMapPos.y][thresholdMapPos.x];
			uint4 icolor = color*255;
			uint4 icolorFloor = icolor/16*16;
			uint4 icolorError = icolor - (icolorFloor);

			color = (icolorFloor + (icolorError>=threshold)*16) / 255.0;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
