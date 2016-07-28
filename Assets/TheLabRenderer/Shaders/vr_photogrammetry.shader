// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================

Shader "Valve/vr_photogrammetry"
{
	Properties
	{
		_Color( "Color", Color ) = ( 1, 1, 1, 1 )
		_MainTex( "Albedo", 2D ) = "white" {}
		//_DetailTex( "Detail Albedo x2", 2D ) = "gray" {}
	}

	SubShader
	{
		Tags { "RenderType" = "Photogrammetry" "PerformanceChecks" = "False" }
		LOD 300

		//-------------------------------------------------------------------------------------------------------------------------------------------------------------
		// Base forward pass (directional light, emission, lightmaps, ...)
		//-------------------------------------------------------------------------------------------------------------------------------------------------------------
		Pass
		{
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }

			Blend SrcAlpha OneMinusSrcAlpha
			//ZWrite [_ZWrite]

			CGPROGRAM
				#pragma target 5.0
				#pragma only_renderers d3d11
				#pragma exclude_renderers gles

				//-------------------------------------------------------------------------------------------------------------------------------------------------------------
				#pragma multi_compile _ D_VALVE_FOG

				//-------------------------------------------------------------------------------------------------------------------------------------------------------------
				#pragma skip_variants SHADOWS_SOFT

				//-------------------------------------------------------------------------------------------------------------------------------------------------------------
				#pragma vertex MainVs
				#pragma fragment MainPs

				// Includes -------------------------------------------------------------------------------------------------------------------------------------------------
				#include "UnityCG.cginc"
				#include "UnityLightingCommon.cginc"
				#include "UnityStandardUtils.cginc"
				#include "UnityStandardInput.cginc"
				#include "vr_utils.cginc"
				#include "vr_lighting.cginc"
				#include "vr_fog.cginc"

				// Structs --------------------------------------------------------------------------------------------------------------------------------------------------
				struct VS_INPUT
				{
					float4 vPositionOs : POSITION;
					float2 vTexCoord0 : TEXCOORD0;
				};

				struct PS_INPUT
				{
					float4 vPositionPs : SV_Position;
					float3 vPositionWs : TEXCOORD0;
					float4 vTextureCoords : TEXCOORD1;

					#if ( D_VALVE_FOG )
						float2 vFogCoords : TEXCOORD6;
					#endif
				};

				// Vars -----------------------------------------------------------------------------------------------------------------------------------------------------
				float g_flValveGlobalVertexScale = 1.0; // Used to "hide" all valve materials for debugging
				float3 g_vShadowColor;
				float4 _Detail_ST;
				float3 g_vPhotogrammetryShadowColor;

				#define g_vColorTint _Color
				#define g_tColor _MainTex
				#define g_tDetail2x _DetailTex

				// MainVs ---------------------------------------------------------------------------------------------------------------------------------------------------
				PS_INPUT MainVs( VS_INPUT i )
				{
					PS_INPUT o = ( PS_INPUT )0;

					// Position
					i.vPositionOs.xyzw *= g_flValveGlobalVertexScale; // Used to "hide" all valve materials for debugging
					o.vPositionWs.xyz = mul( unity_ObjectToWorld, i.vPositionOs.xyzw ).xyz;
					o.vPositionPs.xyzw = mul( UNITY_MATRIX_MVP, i.vPositionOs.xyzw );

					// Texture coordinates
					o.vTextureCoords.xy = TRANSFORM_TEX( i.vTexCoord0.xy, _MainTex );
					o.vTextureCoords.zw = TRANSFORM_TEX( i.vTexCoord0.xy, _Detail );

					#if ( D_VALVE_FOG )
					{
						o.vFogCoords.xy = CalculateFogCoords( o.vPositionWs.xyz );
					}
					#endif

					return o;
				}

				// MainPs ---------------------------------------------------------------------------------------------------------------------------------------------------
				struct PS_OUTPUT
				{
					float4 vColor : SV_Target0;
				};

				PS_OUTPUT MainPs( PS_INPUT i )
				{
					PS_OUTPUT o = ( PS_OUTPUT )0;

					float4 vColorTexel = tex2D( g_tColor, i.vTextureCoords.xy );

					float4 vDetailTexel = tex2D( g_tColor, i.vTextureCoords.zw );

					float flShadowScalarTotal = 1.0;
					[ loop ] for ( int j = 0; j < g_nNumLights; j++ )
					{
						if ( g_vLightShadowIndex_vLightParams[ j ].x != 0.0 )
						{
							float flShadowScalar = ComputeShadow_PCF_3x3_Gaussian( i.vPositionWs.xyz, g_matWorldToShadow[ j ], g_vShadowMinMaxUv[ j ] );
							flShadowScalarTotal = min( flShadowScalarTotal, flShadowScalar );
						}
					}

					// Output color
					o.vColor.rgba = vColorTexel.rgba;
					//o.vColor.rgb *= 2.0 * vDetailTexel.rgb; // FIXME: How to do mod2x correctly in Unity?
					o.vColor.rgb = lerp( g_vPhotogrammetryShadowColor.rgb * o.vColor.rgb, o.vColor.rgb, flShadowScalarTotal );

					// Fog
					#if ( D_VALVE_FOG )
					{
						o.vColor.rgb = ApplyFog( o.vColor.rgb, i.vFogCoords.xy );
					}
					#endif

					// Dither to fix banding artifacts
					o.vColor.rgb += ScreenSpaceDither( i.vPositionPs.xy );

					return o;
				}
			ENDCG
		}

		//-------------------------------------------------------------------------------------------------------------------------------------------------------------
		// Shadow rendering pass
		//-------------------------------------------------------------------------------------------------------------------------------------------------------------
		//Pass
		//{
		//	Name "ShadowCaster"
		//	Tags { "LightMode" = "ShadowCaster" }
		//	
		//	ZWrite On ZTest LEqual
		//
		//	CGPROGRAM
		//		#pragma target 5.0
		//		// TEMPORARY: GLES2.0 temporarily disabled to prevent errors spam on devices without textureCubeLodEXT
		//		#pragma exclude_renderers gles
		//		
		//		// -------------------------------------
		//		#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
		//		#pragma multi_compile_shadowcaster
		//
		//		#pragma vertex vertShadowCaster
		//		#pragma fragment fragShadowCaster
		//
		//		#include "UnityStandardShadow.cginc"
		//	ENDCG
		//}

		//-------------------------------------------------------------------------------------------------------------------------------------------------------------
		// Extracts information for lightmapping, GI (emission, albedo, ...)
		// This pass it not used during regular rendering.
		//-------------------------------------------------------------------------------------------------------------------------------------------------------------
		Pass
		{
			Name "META" 
			Tags { "LightMode"="Meta" }
		
			Cull Off
		
			CGPROGRAM
				#pragma only_renderers d3d11

				#pragma vertex vert_meta
				#pragma fragment frag_meta
		
				#pragma shader_feature _EMISSION
				#pragma shader_feature _METALLICGLOSSMAP
				#pragma shader_feature ___ _DETAIL_MULX2
		
				#include "UnityStandardMeta.cginc"
			ENDCG
		}
	}
}
