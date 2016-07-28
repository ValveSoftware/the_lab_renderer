// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================

Shader "Valve/vr_skybox"
{
	Properties
	{
		_Tint( "Tint Color", Color ) = ( .5, .5, .5, .5 )
		[Gamma] _Exposure( "Exposure", Range( 0, 8 ) ) = 1.0
		_Rotation( "Rotation", Range( 0, 360 ) ) = 0
		[NoScaleOffset] _FrontTex( "Front [+Z]   (HDR)", 2D) = "grey" {}
		[NoScaleOffset] _BackTex( "Back [-Z]   (HDR)", 2D) = "grey" {}
		[NoScaleOffset] _LeftTex( "Left [+X]   (HDR)", 2D) = "grey" {}
		[NoScaleOffset] _RightTex( "Right [-X]   (HDR)", 2D) = "grey" {}
		[NoScaleOffset] _UpTex( "Up [+Y]   (HDR)", 2D) = "grey" {}
		[NoScaleOffset] _DownTex( "Down [-Y]   (HDR)", 2D) = "grey" {}
	}

	SubShader
	{
		Tags
		{
			"Queue"="Background"
			"RenderType"="Background"
			"PreviewType"="Skybox"
		}
		Cull Off
		ZWrite Off
	
		CGINCLUDE
			#pragma target 5.0
			#pragma only_renderers d3d11
			#pragma exclude_renderers gles

			//-------------------------------------------------------------------------------------------------------------------------------------------------------------
			#include "UnityCG.cginc"
			#include "vr_utils.cginc"

			//-------------------------------------------------------------------------------------------------------------------------------------------------------------
			float4 _Tint;
			float _Exposure;
			float _Rotation;
			
			#define g_vTint _Tint
			#define g_flExposure _Exposure
			#define g_flRotation _Rotation
		
			//-------------------------------------------------------------------------------------------------------------------------------------------------------------
			float4 RotateAroundYInDegrees( float4 vPositionOs, float flDegrees )
			{
				float flRadians = flDegrees * UNITY_PI / 180.0;
				float flSin, flCos;
				sincos( flRadians, flSin, flCos );
				float2x2 m = float2x2( flCos, -flSin, flSin, flCos );
				return float4( mul( m, vPositionOs.xz ), vPositionOs.yw ).xzyw;
			}
			
			//-------------------------------------------------------------------------------------------------------------------------------------------------------------
			struct VS_INPUT
			{
				float4 vPositionOs : POSITION;
				float2 vTexcoord : TEXCOORD0;
			};

			struct PS_INPUT
			{
				float4 vPositionPs : SV_POSITION;
				float2 vTexcoord : TEXCOORD0;
			};

			struct PS_OUTPUT
			{
			    float4 vColor : SV_Target0;
			};

			//-------------------------------------------------------------------------------------------------------------------------------------------------------------
			PS_INPUT SkyboxVs( VS_INPUT v )
			{
				PS_INPUT o;
				o.vPositionPs.xyzw = mul( UNITY_MATRIX_MVP, RotateAroundYInDegrees( v.vPositionOs.xyzw, g_flRotation ) );
				o.vTexcoord.xy = v.vTexcoord.xy;
				return o;
			}

			//-------------------------------------------------------------------------------------------------------------------------------------------------------------
			PS_OUTPUT SkyboxPs( PS_INPUT i, sampler2D faceSampler, float4 faceSamplerDecode )
			{
				float4 vSkyboxTexel = tex2D( faceSampler, i.vTexcoord.xy ).rgba;
				float3 vSkyboxLinearColor = DecodeHDR( vSkyboxTexel.rgba, faceSamplerDecode.rgba );

				PS_OUTPUT o;

				o.vColor.rgb = saturate( vSkyboxLinearColor.rgb * g_vTint.rgb * unity_ColorSpaceDouble.rgb * g_flExposure );
				o.vColor.a = 1.0;

				// Dither to fix banding artifacts
				o.vColor.rgb += ScreenSpaceDither( i.vPositionPs.xy );

				return o;
			}

		ENDCG

		Pass
		{
			CGPROGRAM
				#pragma vertex SkyboxVs
				#pragma fragment MainPs
				sampler2D _FrontTex;
				float4 _FrontTex_HDR;
				PS_OUTPUT MainPs( PS_INPUT i ) { return SkyboxPs( i, _FrontTex, _FrontTex_HDR ); }
			ENDCG 
		}

		Pass
		{
			CGPROGRAM
				#pragma vertex SkyboxVs
				#pragma fragment MainPs
				sampler2D _BackTex;
				float4 _BackTex_HDR;
				PS_OUTPUT MainPs( PS_INPUT i ) { return SkyboxPs( i, _BackTex, _BackTex_HDR ); }
			ENDCG 
		}

		Pass
		{
			CGPROGRAM
				#pragma vertex SkyboxVs
				#pragma fragment MainPs
				sampler2D _LeftTex;
				float4 _LeftTex_HDR;
				PS_OUTPUT MainPs( PS_INPUT i ) { return SkyboxPs( i, _LeftTex, _LeftTex_HDR ); }
			ENDCG
		}
		Pass
		{
			CGPROGRAM
				#pragma vertex SkyboxVs
				#pragma fragment MainPs
				sampler2D _RightTex;
				float4 _RightTex_HDR;
				PS_OUTPUT MainPs( PS_INPUT i ) { return SkyboxPs( i, _RightTex, _RightTex_HDR ); }
			ENDCG
		}	
		Pass
		{
			CGPROGRAM
				#pragma vertex SkyboxVs
				#pragma fragment MainPs
				sampler2D _UpTex;
				float4 _UpTex_HDR;
				PS_OUTPUT MainPs( PS_INPUT i ) { return SkyboxPs( i, _UpTex, _UpTex_HDR ); }
			ENDCG
		}	
		Pass
		{
			CGPROGRAM
				#pragma vertex SkyboxVs
				#pragma fragment MainPs
				sampler2D _DownTex;
				float4 _DownTex_HDR;
				PS_OUTPUT MainPs( PS_INPUT i ) { return SkyboxPs( i, _DownTex, _DownTex_HDR ); }
			ENDCG
		}
	}
}
