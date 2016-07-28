// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================

Shader "Valve/Internal/vr_cast_shadows"
{
	SubShader
	{
		Tags { "RenderType" = "Opaque" "PerformanceChecks" = "False" }
		LOD 300

		Pass
		{
			Name "ValveShadowCaster"
			Tags { "LightMode" = "ForwardBase" }
			//Tags { "LightMode" = "ShadowCaster" }

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
					// From: Ignacio Castaño http://the-witness.net/news/2013/09/shadow-mapping-summary-part-1/
					float cos_alpha = saturate( dot( N, L ) );
					float offset_scale_N = sqrt( 1 - ( cos_alpha * cos_alpha ) ); // sin( acos( L·N ) )
					float offset_scale_L = offset_scale_N / cos_alpha; // tan( acos( L·N ) )
					return float2( offset_scale_N, min( 2.0, offset_scale_L ) );
				}

				VertexOutput MainVs( VertexInput i )
				{
					VertexOutput o;

					#if ( MATRIX_PALETTE_SKINNING )
					{
						MatrixPaletteSkinning( i.vPositionOs.xyzw, i.vBoneIndices.xyzw );
					}
					#endif

					//o.vPositionPs.xyzw = mul( UNITY_MATRIX_MVP, i.vPositionOs.xyzw );

					float3 vNormalWs = UnityObjectToWorldNormal( i.vNormalOs.xyz );
					float3 vPositionWs = mul( unity_ObjectToWorld, i.vPositionOs.xyzw ).xyz;
					float2 vShadowOffsets = GetShadowOffsets( vNormalWs.xyz, g_vLightDirWs.xyz );
					//vPositionWs.xyz -= vShadowOffsets.x * vNormalWs.xyz / 100;
					vPositionWs.xyz += vShadowOffsets.y * g_vLightDirWs.xyz / 1000;
					o.vPositionPs.xyzw = mul( UNITY_MATRIX_MVP, float4( mul( unity_WorldToObject, float4( vPositionWs.xyz, 1.0 ) ).xyz, 1.0 ) );

					return o;
				}

				float4 MainPs( VertexOutput i ) : SV_Target
				{
					return float4( 0.0, 0.0, 0.0, 0.0 );
				}
			ENDCG
		}
	}
}
