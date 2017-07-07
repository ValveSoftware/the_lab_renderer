

// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================
// Modified to include  alpha cutout and alpha blended shadows
// Also replaced the biasing function with Unity's own implementation
// of Ignacio Casta隳's suggestions
// Simon Windmill 03/19/2017

Shader  "Valve/Internal/vr_cast_shadows"
{

	SubShader
	{
		Tags { "RenderType" = "Opaque" "PerformanceChecks" = "False" }
		LOD 300

		Pass
		{
		 	Name "ValveShadowCaster"
			Tags { "LightMode" = "ForwardBase" }


			ZWrite On
			ZTest LEqual
			 ColorMask 0
			Blend Off
			Offset 2.5, 1 // http://docs.unity3d.com/Manual/SL-CullAndDepth.html

			CGPROGRAM
			 #pragma target 5.0
			#pragma only_renderers d3d11
			//#pragma multi_compile_shadowcaster

			// Valve custom dynamic combos
			 #pragma multi_compile _ MATRIX_PALETTE_SKINNING_1BONE

			#pragma vertex MainVs
			#pragma fragment MainPs

			#include "UnityCG.cginc"
		 	#include "../Shaders/vr_matrix_palette_skinning.cginc"

			struct VertexInput
			{

				float4 vPositionOs : POSITION;
		 		float3 vNormalOs : NORMAL;

				#if ( MATRIX_PALETTE_SKINNING )
					float4 vBoneIndices : COLOR;
				 #endif
			};

			struct VertexOutput
			{

				float4 vPositionPs : SV_POSITION;
			};
			
			
			float3 g_vLightDirWs = float3( 0.0, 0.0, 0.0 );

			float2 GetShadowOffsets( float3 N, float3 L )
				{
					// From: Ignacio Casta隳 http://the-witness.net/news/2013/09/shadow-mapping-summary-part-1/
					float cos_alpha = saturate( dot( N, L ) );
					float offset_scale_N = sqrt( 1 - ( cos_alpha * cos_alpha ) ); // sin( acos( L意 ) )
					float offset_scale_L = offset_scale_N / cos_alpha; // tan( acos( L意 ) )
					return float2( offset_scale_N, min( 2.0, offset_scale_L ) );
				}


		 	VertexOutput MainVs(VertexInput i)
			{
				VertexOutput o;


				#if ( MATRIX_PALETTE_SKINNING )

				 {
					MatrixPaletteSkinning(i.vPositionOs.xyzw, i.vBoneIndices.xyzw);





				}
				#endif
			
					float3 vNormalWs = UnityObjectToWorldNormal( i.vNormalOs.xyz );
					float3 vPositionWs = mul( unity_ObjectToWorld, i.vPositionOs.xyzw ).xyz;
					float2 vShadowOffsets = GetShadowOffsets( vNormalWs.xyz, g_vLightDirWs.xyz );
					//vPositionWs.xyz -= vShadowOffsets.x * vNormalWs.xyz / 100;
					vPositionWs.xyz += vShadowOffsets.y * g_vLightDirWs.xyz / 1000;
					o.vPositionPs.xyzw = UnityObjectToClipPos( float4( mul( unity_WorldToObject, float4( vPositionWs.xyz, 1.0 ) ).xyz, 1.0 ) );

				 o.vPositionPs = UnityClipSpaceShadowCasterPos(i.vPositionOs.xyz, i.vNormalOs);
				 o.vPositionPs = UnityApplyLinearShadowBias(o.vPositionPs);

				 return o;
			}

			float4 MainPs(VertexOutput i) : SV_Target
			{
				return float4(0.0, 0.0, 0.0,  0.0);
			}
			ENDCG
		}
	}

	SubShader
	{
		Tags{ "RenderType" = "TransparentCutout" "PerformanceChecks" = "False" }
	 	LOD 300

		Pass
		{
			Name "ValveShadowCaster"
			Tags{ "LightMode" = "ForwardBase" }

			ZWrite On
		 	ZTest LEqual
			ColorMask 0
			Blend Off
			Offset 2.5, 1 // http://docs.unity3d.com/Manual/SL-CullAndDepth.html

			 CGPROGRAM
			#pragma target 5.0
			#pragma only_renderers d3d11
			//#pragma multi_compile_shadowcaster

			// Valve  custom dynamic combos
			#pragma multi_compile _ MATRIX_PALETTE_SKINNING_1BONE

			#pragma vertex MainVs
			#pragma fragment MainPs

			 #include "UnityCG.cginc"
			#include "../Shaders/vr_matrix_palette_skinning.cginc"

			struct VertexInput
			{
				 float4 vPositionOs : POSITION;
				float3 vNormalOs : NORMAL;
				float2 uv0 : TEXCOORD0;

			#if ( MATRIX_PALETTE_SKINNING )
		 		float4 vBoneIndices : COLOR;
			#endif
			};

			struct VertexOutput
			{
				 float4 vPositionPs : SV_POSITION;
				float2 uv0 : TEXCOORD0;
			};
			
			
			float3 g_vLightDirWs = float3( 0.0, 0.0, 0.0 );

			float2 GetShadowOffsets( float3 N, float3 L )
				{
					// From: Ignacio Casta隳 http://the-witness.net/news/2013/09/shadow-mapping-summary-part-1/
					float cos_alpha = saturate( dot( N, L ) );
					float offset_scale_N = sqrt( 1 - ( cos_alpha * cos_alpha ) ); // sin( acos( L意 ) )
					float offset_scale_L = offset_scale_N / cos_alpha; // tan( acos( L意 ) )
					return float2( offset_scale_N, min( 2.0, offset_scale_L ) );
				}


			sampler2D _MainTex;
			fixed _Cutoff;
			float4 _MainTex_ST;
		
			VertexOutput MainVs(VertexInput i)
			{
				VertexOutput o;

			#if ( MATRIX_PALETTE_SKINNING )
			 {
				MatrixPaletteSkinning(i.vPositionOs.xyzw, i.vBoneIndices.xyzw);
			}
			#endif
			
				float3 vNormalWs = UnityObjectToWorldNormal( i.vNormalOs.xyz );
					float3 vPositionWs = mul( unity_ObjectToWorld, i.vPositionOs.xyzw ).xyz;
					float2 vShadowOffsets = GetShadowOffsets( vNormalWs.xyz, g_vLightDirWs.xyz );
					//vPositionWs.xyz -= vShadowOffsets.x * vNormalWs.xyz / 100;
					vPositionWs.xyz += vShadowOffsets.y * g_vLightDirWs.xyz / 1000;
					o.vPositionPs.xyzw = UnityObjectToClipPos( float4( mul( unity_WorldToObject, float4( vPositionWs.xyz, 1.0 ) ).xyz, 1.0 ) );

				//o.vPositionPs =  UnityClipSpaceShadowCasterPos(i.vPositionOs.xyz, i.vNormalOs);
				//o.vPositionPs = UnityApplyLinearShadowBias(o.vPositionPs);

				o.uv0 =  i.uv0;

				return o;
			}

			float4 MainPs(VertexOutput i) : SV_Target
			{
				float2  newUV = TRANSFORM_TEX(i.uv0, _MainTex);
				 half alpha = tex2D(_MainTex, newUV).a;
				clip(alpha - _Cutoff);

				return float4(0.0, 0.0, 0.0, 0.0);

			}
			 ENDCG
		}
	}

	SubShader
	{
		Tags{ "RenderType" = "Transparent" "PerformanceChecks" = "False" }
		LOD 300

		Pass
		{
		 	Name "ValveShadowCaster"
			Tags{ "LightMode" = "ForwardBase" }

			ZWrite On
			ZTest LEqual
			 ColorMask 0
			Blend Off
			Offset 2.5, 1 // http://docs.unity3d.com/Manual/SL-CullAndDepth.html

			CGPROGRAM
			 #pragma target 5.0
			#pragma only_renderers d3d11
			//#pragma multi_compile_shadowcaster

			// Valve custom dynamic combos
			 #pragma multi_compile _ MATRIX_PALETTE_SKINNING_1BONE

			#pragma vertex MainVs
			#pragma fragment MainPs

			#include "UnityCG.cginc"
		 	#include "../Shaders/vr_matrix_palette_skinning.cginc"

			struct VertexInput
			{
				float4 vPositionOs : POSITION;
		 		float3 vNormalOs : NORMAL;
				float2 uv0 : TEXCOORD0;

		#if ( MATRIX_PALETTE_SKINNING )
				float4 vBoneIndices :  TEXCOORD3;
		#endif

				fixed4 color : COLOR;
			};

			struct VertexOutput
			{
				 float4 vPositionPs : SV_POSITION;
				float2 uv0 : TEXCOORD0;

				fixed4 color : COLOR;
			};

			struct  VertexOutputClip
			{
				UNITY_VPOS_TYPE vpos : VPOS;
				float2 uv0 : TEXCOORD0;
				fixed4  color : COLOR;
			};
			
			
			float3 g_vLightDirWs = float3( 0.0, 0.0, 0.0 );

			float2 GetShadowOffsets( float3 N, float3 L )
				{
					// From: Ignacio Casta隳 http://the-witness.net/news/2013/09/shadow-mapping-summary-part-1/
					float cos_alpha = saturate( dot( N, L ) );
					float offset_scale_N = sqrt( 1 - ( cos_alpha * cos_alpha ) ); // sin( acos( L意 ) )
					float offset_scale_L = offset_scale_N / cos_alpha; // tan( acos( L意 ) )
					return float2( offset_scale_N, min( 2.0, offset_scale_L ) );
				}


			sampler2D _MainTex;
			sampler3D _DitherMaskLOD;
			half4 _Color;
			fixed  _Cutoff;
			float4 _MainTex_ST;

			VertexOutput MainVs(VertexInput i)
			{


				VertexOutput o;

			#if ( MATRIX_PALETTE_SKINNING )
		 	{
				MatrixPaletteSkinning(i.vPositionOs.xyzw, i.vBoneIndices.xyzw);
			}
			#endif
				float3 vNormalWs = UnityObjectToWorldNormal( i.vNormalOs.xyz );
					float3 vPositionWs = mul( unity_ObjectToWorld, i.vPositionOs.xyzw ).xyz;
					float2 vShadowOffsets = GetShadowOffsets( vNormalWs.xyz, g_vLightDirWs.xyz );
					//vPositionWs.xyz -= vShadowOffsets.x * vNormalWs.xyz / 100;
					vPositionWs.xyz += vShadowOffsets.y * g_vLightDirWs.xyz / 1000;
					o.vPositionPs.xyzw = UnityObjectToClipPos( float4( mul( unity_WorldToObject, float4( vPositionWs.xyz, 1.0 ) ).xyz, 1.0 ) );
			
				 o.vPositionPs = UnityClipSpaceShadowCasterPos(i.vPositionOs.xyz, i.vNormalOs);
				o.vPositionPs = UnityApplyLinearShadowBias(o.vPositionPs);

				 o.uv0 = i.uv0;

				o.color = i.color;






				return o;
			}


			float4 MainPs(VertexOutputClip i) :  SV_Target
			{
				float2  newUV = TRANSFORM_TEX(i.uv0, _MainTex);
				half alpha = tex2D(_MainTex, newUV).a * _Color.a * i.color.a;







				// magic numbers explained in  http://catlikecoding.com/unity/tutorials/rendering/part-12/
				float dither = tex3D(_DitherMaskLOD, float3(i.vpos.xy * 0.25, alpha * 0.9475)).a;
			 	clip(dither - 0.01);





				return float4(0.0, 0.0, 0.0, 0.0);
			}

			ENDCG
		}
	}
}