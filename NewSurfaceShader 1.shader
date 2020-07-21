// Upgrade NOTE: commented out 'float3 _WorldSpaceCameraPos', a built-in variable

// Upgrade NOTE: commented out 'float3 _WorldSpaceCameraPos', a built-in variable

// Upgrade NOTE: commented out 'float3 _WorldSpaceCameraPos', a built-in variable

Shader "Custom/NewSurfaceShader 1" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_MaxIterations ("Max Iterations", Int) = 64
		[Toggle(_GENERATE_NORMALS)] _GenerateNormalsToggle ("Generate Custom Normals", Float) = 1
		[Toggle(_RENDER_DEBUGINFO)] _DebugToggle ("View Debug", Float) = 1
	}
	SubShader {
		Tags {
			"RenderType" = "Transparent"
			"Queue" = "Transparent"
		}
		// LOD 200

		CGPROGRAM

		#include "util/map_range.cginc"
		#include "util/glsl_style_modulo.cginc"

		#pragma shader_feature _RENDER_DEBUGINFO
		#pragma shader_feature _GENERATE_NORMALS

		#pragma surface surf Standard fullforwardshadows alpha:blend vertex:vert finalcolor:finalColor

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;

		struct Input {
			float3 worldPos;
			float4 tangent;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;
		int _MaxIterations;

		struct SphereTraceResult {
			int iterations;
			bool collisionOccurred;
			float3 collisionNormal;
			float3 collisionPosition;
		};

		float worldSDF(float3 p) {
			return length(p) - .2;
		}
		
		SphereTraceResult sphereTrace(float3 initialRayPosition, float3 rayDirection) {
			SphereTraceResult ret;
			float3 rayPosition = initialRayPosition;
			for(ret.iterations = 0; ret.iterations < _MaxIterations; ret.iterations++) {
				float d = worldSDF(rayPosition);
				if(d < 1e-4) {
					ret.collisionOccurred = true;
					ret.collisionPosition = rayPosition;
					// TODO collision normal
					return ret;
				}
				rayPosition += rayDirection * d;
			}
			return ret;
		}

		void vert(inout appdata_full v, out Input o) {
			UNITY_INITIALIZE_OUTPUT(Input, o);
			// o.worldPos = mul(unity_ObjectToWorld, v.vertex);
			o.tangent = v.tangent;
		}

		void surf(Input IN, inout SurfaceOutputStandard o) {
			float3 debug = float3(0,0,0);

			// setup material stuff
			o.Albedo = _Color.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = _Color.a;

			#ifdef _GENERATE_NORMALS
				o.Normal = float3(0,0,1);
			#endif

			SphereTraceResult result = sphereTrace(IN.worldPos, normalize(IN.worldPos - _WorldSpaceCameraPos));
			// debug = result.iterations / float(_MaxIterations);
			debug = IN.tangent.xyz;

			#ifdef _RENDER_DEBUGINFO
				o.Emission = debug;
			#endif
		}

		void finalColor(Input IN, SurfaceOutputStandard o, inout fixed4 color) {
			#ifdef _RENDER_DEBUGINFO
				color.rgb = o.Emission;
				color.a = 1;
			#endif
		}
		ENDCG
	}
	FallBack "Diffuse"
}
