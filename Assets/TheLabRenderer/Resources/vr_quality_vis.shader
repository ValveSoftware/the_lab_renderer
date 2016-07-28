// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================

Shader "Valve/Internal/vr_quality_vis"
{
	SubShader
	{
		Pass
		{
			Name "ValveShadowVis"

			ZTest Always
			Cull Off
			ZWrite On

			CGPROGRAM
				#pragma target 5.0
				#pragma only_renderers d3d11

				#pragma vertex MainVs
				#pragma fragment MainPs

				#include "UnityCG.cginc"

				struct VS_INPUT
				{
					float4 vPositionOs : POSITION;
					float2 vTexCoord : TEXCOORD0;
				};

				struct PS_INPUT
				{
					float4 vPositionPs : SV_Position;
					sample float2 vTexCoord : TEXCOORD0;
				};

				struct PS_OUTPUT
				{
					float4 vColor : SV_Target0;
					float flDepth : SV_Depth;
				};

				PS_INPUT MainVs( VS_INPUT i )
				{
					PS_INPUT o;
					o.vPositionPs.xyzw = mul( UNITY_MATRIX_MVP, i.vPositionOs.xyzw );
					o.vTexCoord.xy = float2( i.vTexCoord.x, 1.0 - i.vTexCoord.y );
					return o;
				}

				uint g_nNumBins = 10;
				uint g_nDefaultBin = 6;
				uint g_nCurrentBin = 5;
				uint g_nLastFrameInBudget = 1;

				PS_OUTPUT MainPs( PS_INPUT i )
				{
					PS_OUTPUT o;
					o.vColor.rgba = float4( 0.0, 0.0, 0.0, 1.0 );

					uint nBin = i.vTexCoord.x * g_nNumBins;

					if ( i.vTexCoord.y <= 0.1 )
					{
						// Thin bar showing colors
						if ( nBin == 0 )
							o.vColor.rgb = float3( 0.5, 0.0, 0.0 );
						else if ( nBin < g_nDefaultBin )
							o.vColor.rgb = float3( 0.5, 0.5, 0.0 );
						else
							o.vColor.rgb = float3( 0.0, 0.5, 0.0 );
					}
					else if ( nBin == g_nCurrentBin )
					{
						// Current bin
						if ( g_nLastFrameInBudget == 0 )
							o.vColor.rgb = float3( 0.5, 0.0, 0.0 );
						else if ( nBin < g_nDefaultBin )
							o.vColor.rgb = float3( 0.5, 0.5, 0.0 );
						else
							o.vColor.rgb = float3( 0.0, 0.5, 0.0 );
					}
					else
					{
						// Gray bins
						if ( nBin & 0x1 )
							o.vColor.rgb = float3( 0.02, 0.02, 0.02 );
						else
							o.vColor.rgb = float3( 0.03, 0.03, 0.03 );
					}

					// Force z to near plane
					o.flDepth = 0.0;

					return o;
				}
			ENDCG
		}
	}
}
