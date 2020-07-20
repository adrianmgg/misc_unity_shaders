Shader "Custom/NewSurfaceShader" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_MaxIterations ("Max Iterations", Int) = 64
	}
	SubShader {
		Tags {
			"RenderType" = "Transparent"
			"Queue" = "Transparent"
		}
		//LOD 200

		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		// #pragma surface surf Standard fullforwardshadows alpha:blend
		#pragma surface surf Standard fullforwardshadows alpha:blend

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
			float3 viewDir;
			float3 worldPos;
			float3 worldNormal;
			// float3 worldRefl;
			// INTERNAL_DATA
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;
		int _MaxIterations;

		float3 fmod_(float3 x, float3 y) {
			return abs(fmod(x,y)) * sign(y);
		}

		#define _difference(T) T difference(T a, T b) {return abs(a - b);}
		_difference(float) _difference(float2) _difference(float3) _difference(float4)
		#undef _difference

		// https://gamedev.stackexchange.com/a/147894
		float map(float value, float min1, float max1, float min2, float max2) {
			return ((value - min1) / (max1 - min1)) * (max2 - min2) + min2;
		}

		// https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
		float sphereSDF(float3 p, float r) {
			return length(p) - r;
		}
		float cylinderSDF(float3 p, float3 c) {
			return length(p.xz-c.xy)-c.z;
		}
		float boxSDF(float3 p, float3 b) {
			float3 q = abs(p) - b;
			return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
		}
		float boundingBoxSDF(float3 p, float3 b, float e) {
			p = abs(p  )-b;
			float3 q = abs(p+e)-e;
			return min(min(
				length(max(float3(p.x,q.y,q.z),0.0))+min(max(p.x,max(q.y,q.z)),0.0),
				length(max(float3(q.x,p.y,q.z),0.0))+min(max(q.x,max(p.y,q.z)),0.0)),
				length(max(float3(q.x,q.y,p.z),0.0))+min(max(q.x,max(q.y,p.z)),0.0));
		}
		float3 repeatDomain(float3 p, float3 d) {
			// fmod(a,b) == fract(a*b)/b
			return fmod_(p+0.5*d,d) - 0.5*d;
		}

		float sdf(float3 p) {
			return sphereSDF( repeatDomain(p, 2) , .25);
			// return sphereSDF(
			// 	repeatDomain(p+ float3(_Time.y,0,0), 2),
			// 	map(sin(_Time.y), -1, 1, .1, .3)
			// );
			// float d2 = boundingBoxSDF(repeatDomain(p + float3(_Time.y,0,0), 1), .5, .0125/2);
			// return min(d1, d2);
			// return boxSDF(p, .25);
			// return boundingBoxSDF(repeatDomain(p, 1), .5, .0125);
		}

		// https://iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
		float3 calcNormal(float3 p) {
			const float h = 0.0001; // replace by an appropriate value
			const float2 k = float2(1,-1);
			return normalize( k.xyy*sdf( p + k.xyy*h ) + 
							k.yyx*sdf( p + k.yyx*h ) + 
							k.yxy*sdf( p + k.yxy*h ) + 
							k.xxx*sdf( p + k.xxx*h ) );
		}

		float3 worldNormalToTangentNormal(float3 undistortedWorldNormal, float3 generatedWorldNormal) {
			return float3(0,0,1);
		}

		void sphereTrace(float3 rayInitialPosition, float3 rayDirection, int maxIterations, out bool collisionOccurred, out float3 collisionNormal) {
			collisionOccurred = false;

			float3 rayPosition = rayInitialPosition;
			for(int numIterations = 0; numIterations < _MaxIterations; numIterations++) {
				float dist = sdf(rayPosition);
				if(dist < 1e-3) {
					collisionOccurred = true;
					collisionNormal = calcNormal(rayPosition);
					return;
				}
				rayPosition += rayDirection * dist;
			}
		}

		// #define APPLY_GENERATED_NORMALS
		// #define APPLY_TRANSPARENCY

		// #define DEBUG_VIEW_GENERATED_WORLDNORMALS
		// #define DEBUG_VIEW_GENERATED_TANGENTNORMALS
		// #define DEBUG_VIEW_WORLDPOS
		#define DEBUG_VIEW_VIEWDIR

		void surf (Input IN, inout SurfaceOutputStandard o) {
			float3 worldNormal = IN.worldNormal;
			// float3 worldNormal = WorldNormalVector(IN, o.Normal);

			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;

			bool collisionOccurred;
			float3 collisionNormal;
			sphereTrace(IN.worldPos, -IN.viewDir, _MaxIterations, collisionOccurred, collisionNormal);

			#ifdef APPLY_GENERATED_NORMALS
				if(collisionOccurred) o.Normal = worldNormalToTangentNormal(worldNormal, collisionNormal);
			#endif

			#if defined(DEBUG_VIEW_GENERATED_WORLDNORMALS)
				if(collisionOccurred) o.Emission = collisionNormal;
			#elif defined(DEBUG_VIEW_GENERATED_TANGENTNORMALS)
				if(collisionOccurred) o.Emission = worldNormalToTangentNormal(worldNormal, collisionNormal);
			#elif defined(DEBUG_VIEW_WORLDPOS)
				o.Emission = IN.worldPos;
			#elif defined(DEBUG_VIEW_VIEWDIR)
				o.Emission = IN.viewDir;
			#endif

			o.Albedo = c.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			// o.Albedo = float3(0,0,0);
			// o.Emission = collisionNormal;

			// if(collisionOccurred) o.Emission = difference(float3(0,0,1), worldNormalToTangentNormal(worldNormal, collisionNormal));

			#ifdef APPLY_TRANSPARENCY
				o.Alpha = collisionOccurred;
			#else
				o.Alpha = 1;
			#endif
		}

		ENDCG
	}
	FallBack "Diffuse"
}
