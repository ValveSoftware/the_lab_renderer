// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================

Shader "Valve/Internal/vr_shadow_vis"
{
	SubShader
	{
		Pass
		{
			Name "ValveShadowVis"

			ZTest Always
			Cull Off
			ZWrite Off

			CGPROGRAM
				#pragma target 5.0
				#pragma only_renderers d3d11

				#pragma vertex MainVs
				#pragma fragment MainPs

				#include "UnityCG.cginc"

				#define VALVE_DECLARE_SHADOWMAP( tex ) Texture2D tex; SamplerComparisonState sampler##tex
				#define VALVE_SAMPLE_SHADOW( tex, coord ) tex.SampleCmpLevelZero( sampler##tex, (coord).xy, (coord).z )
				VALVE_DECLARE_SHADOWMAP( g_tShadowBuffer );

				struct VertexInput
				{
					float4 vPositionOs : POSITION;
					float2 vTexCoord : TEXCOORD0;
				};

				struct VertexOutput
				{
					float4 vPositionPs : SV_POSITION;
					float2 vTexCoord : TEXCOORD0;
				};

				VertexOutput MainVs( VertexInput i )
				{
					VertexOutput o;
					o.vPositionPs.xyzw = mul( UNITY_MATRIX_MVP, i.vPositionOs.xyzw );
					o.vTexCoord.xy = float2( i.vTexCoord.x, 1.0 - i.vTexCoord.y );
					return o;
				}

				float4 MainPs( VertexOutput i ) : SV_Target
				{
					#define NUM_SAMPLES 128.0
					float flSum = 0.0;
					for ( int j = 0; j < NUM_SAMPLES; j++ )
					{
						flSum += ( 1.0 / NUM_SAMPLES ) * ( VALVE_SAMPLE_SHADOW( g_tShadowBuffer, float3( i.vTexCoord.xy, j / NUM_SAMPLES ) ).r );
					}

					flSum = pow( flSum, 2.0 );

					float4 o = float4( flSum, flSum, flSum, 1.0 );
					return o;
				}
			ENDCG
		}
	}
}
