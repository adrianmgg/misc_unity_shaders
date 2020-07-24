Shader "Custom/SphereTracingWithCustomNormals" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_MaxIterations ("Max Iterations", Int) = 64
		_Epsilon ("Epsilon", Float) = 0.0001
		[Toggle(_RENDER_DEBUGINFO)] _DebugToggle ("View Debug", Float) = 1
		[KeywordEnum(Camera, Surface)] _TraceStartAt ("Start Trace At", Float) = 0
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
		#include "util/sdf.cginc"

		#include "UnityPBSLighting.cginc"

		#pragma shader_feature_local _RENDER_DEBUGINFO
		#pragma multi_compile_local _TRACESTARTAT_CAMERA _TRACESTARTAT_SURFACE

		#pragma surface surf Foo fullforwardshadows alpha:blend vertex:vert finalcolor:finalColor

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;

		struct Input {
			float3 worldPos;
			float3 objectPos;
			float4 tangent;
			float3 normal;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;
		int _MaxIterations;
		float _Epsilon;

		struct SphereTraceResult {
			int iterations;
			bool collisionOccurred;
			float3 collisionNormal;
			float3 collisionPosition;
		};

		// modified version of SurfaceOutputStandard from UnityPBSLighting.cginc
		struct SurfaceOutputFoo {
			// ==== stuff that was already there ====
			fixed3 Albedo;      // base (diffuse or specular) color
			float3 Normal;      // tangent space normal, if written
			half3 Emission;
			half Metallic;      // 0=non-metal, 1=metal
			// Smoothness is the user facing name, it should be perceptual smoothness but user should not have to deal with it.
			// Everywhere in the code you meet smoothness it is perceptual smoothness
			half Smoothness;    // 0=rough, 1=smooth
			half Occlusion;     // occlusion (default 1)
			fixed Alpha;        // alpha for transparencies
			
			// ==== stuff I added ====
			float3 WorldSpaceNormal;
		};

		float worldSDF(float3 p) {
			// ==== smooth union demo ====
			return opSmoothUnion(
				sphereSDF(translateSpace(p, float3(0,.25,0)), .25),
				sphereSDF(translateSpace(p, float3(0,-.25,0)), .25),
				map(_SinTime.w, -1, 1, 0, .25)
			);

			// ==== tile space demo ====
			// return sphereSDF(repeatSpace(p, 1), .25);

			// ==== ====
			// return mandelbulbSDF(p, map(_SinTime.y, -1, 1, 4, 8), 32);
			// return mandelbulbSDF(p*4, map(_SinTime.y, -1, 1, 4, 8), 8)/4;
		}

		// https://iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
		float3 calculateSDFNormal(float3 p) {
			const float2 k = float2(1,-1);
			return normalize(
				k.xyy * worldSDF(p + k.xyy*_Epsilon)
				+ k.yyx * worldSDF(p + k.yyx*_Epsilon)
				+ k.yxy * worldSDF(p + k.yxy*_Epsilon)
				+ k.xxx * worldSDF(p + k.xxx*_Epsilon)
			);
		}
		
		SphereTraceResult sphereTrace(float3 initialRayPosition, float3 rayDirection) {
			SphereTraceResult ret;
			float3 rayPosition = initialRayPosition;
			float insideFlip = sign(worldSDF(initialRayPosition));
			for(ret.iterations = 0; ret.iterations < _MaxIterations; ret.iterations++) {
				float d = worldSDF(rayPosition) * insideFlip;
				if(d < _Epsilon) {
					ret.collisionOccurred = true;
					ret.collisionPosition = rayPosition;
					ret.collisionNormal = calculateSDFNormal(rayPosition);
					return ret;
				}
				rayPosition += rayDirection * d;
			}
			return ret;
		}

		void vert(inout appdata_full v, out Input o) {
			UNITY_INITIALIZE_OUTPUT(Input, o);
			o.objectPos = v.vertex;
			o.tangent = v.tangent;
			o.normal = v.normal;
		}

		void surf(Input IN, inout SurfaceOutputFoo o) {
			float3 debug = float3(0,0,0);

			// setup material stuff
			o.Albedo = _Color.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = _Color.a;

			SphereTraceResult result = sphereTrace(
				#if defined (_TRACESTARTAT_CAMERA)
					_WorldSpaceCameraPos,
				#elif defined(_TRACESTARTAT_SURFACE)
					IN.worldPos,
				#else
					"https://xkcd.com/2200/"
				#endif
				normalize(IN.worldPos - _WorldSpaceCameraPos)
			);
			
			// if I assign to o.Normal here unity assumes it's in tangent space so I use this variable instead
			o.WorldSpaceNormal = result.collisionNormal;
			o.Alpha = result.collisionOccurred;
			
			#ifdef _RENDER_DEBUGINFO
				o.Emission = debug;
			#endif
		}

		// modified version of LightingStandard from UnityPBSLighting.cginc
		half4 LightingFoo (SurfaceOutputFoo s, float3 viewDir, UnityGI gi) {
			s.Normal = normalize(s.WorldSpaceNormal);
			half oneMinusReflectivity;
			half3 specColor;
			s.Albedo = DiffuseAndSpecularFromMetallic (s.Albedo, s.Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

			// shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
			// this is necessary to handle transparency in physically correct way - only diffuse component gets affected by alpha
			half outputAlpha;
			s.Albedo = PreMultiplyAlpha (s.Albedo, s.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);

			half4 c = UNITY_BRDF_PBS (s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);
			c.a = outputAlpha;
			return c;
		}

		// modified version of LightingStandard_GI from UnityPBSLighting.cginc
		inline void LightingFoo_GI (SurfaceOutputFoo s, UnityGIInput data, inout UnityGI gi) {
			#if defined(UNITY_PASS_DEFERRED) && UNITY_ENABLE_REFLECTION_BUFFERS
				gi = UnityGlobalIllumination(data, s.Occlusion, s.Normal);
			#else
				Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.Smoothness, data.worldViewDir, s.Normal, lerp(unity_ColorSpaceDielectricSpec.rgb, s.Albedo, s.Metallic));
				gi = UnityGlobalIllumination(data, s.Occlusion, s.Normal, g);
			#endif
		}

		void finalColor(Input IN, SurfaceOutputFoo o, inout fixed4 color) {
			#ifdef _RENDER_DEBUGINFO
				color.rgb = o.Emission;
				color.a = 1;
			#endif
		}
		ENDCG
	}
	FallBack "Diffuse"
}
