// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================

Shader "Valve/vr_standard"
{
	Properties
	{
		[Toggle( S_UNLIT )] g_bUnlit( "g_bUnlit", Int ) = 0

		_Color( "Color", Color ) = ( 1, 1, 1, 1 )
		_MainTex( "Albedo", 2D ) = "white" {}
		
		_Cutoff( "Alpha Cutoff", Range( 0.0, 1.0 ) ) = 0.5

		_Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
		_SpecColor("Specular", Color) = (0.2,0.2,0.2)
		_SpecGlossMap("Specular", 2D) = "white" {}

		g_flReflectanceMin( "g_flReflectanceMin", Range( 0.0, 1.0 ) ) = 0.0
		g_flReflectanceMax( "g_flReflectanceMax", Range( 0.0, 1.0 ) ) = 1.0
		[HideInInspector] g_flReflectanceScale( "g_flReflectanceScale", Range( 0.0, 1.0 ) ) = 1.0
		[HideInInspector] g_flReflectanceBias( "g_flReflectanceBias", Range( 0.0, 1.0 ) ) = 0.0

		[Gamma] _Metallic( "Metallic", Range( 0.0, 1.0 ) ) = 0.0
		_MetallicGlossMap( "Metallic", 2D ) = "white" {}

		_BumpScale( "Scale", Float ) = 1.0
		[Normal] _BumpMap( "Normal Map", 2D ) = "bump" {}

		_Parallax ( "Height Scale", Range ( 0.005, 0.08 ) ) = 0.02
		_ParallaxMap ( "Height Map", 2D ) = "black" {}

		_OcclusionStrength( "Strength", Range( 0.0, 1.0 ) ) = 1.0
		_OcclusionMap( "Occlusion", 2D ) = "white" {}
		_OcclusionStrengthDirectDiffuse( "StrengthDirectDiffuse", Range( 0.0, 1.0 ) ) = 1.0
		_OcclusionStrengthDirectSpecular( "StrengthDirectSpecular", Range( 0.0, 1.0 ) ) = 1.0
		_OcclusionStrengthIndirectDiffuse( "StrengthIndirectDiffuse", Range( 0.0, 1.0 ) ) = 1.0
		_OcclusionStrengthIndirectSpecular( "StrengthIndirectSpecular", Range( 0.0, 1.0 ) ) = 1.0

		g_flCubeMapScalar( "Cube Map Scalar", Range( 0.0, 2.0 ) ) = 1.0

		_EmissionColor( "Color", Color ) = ( 0, 0, 0 )
		_EmissionMap( "Emission", 2D ) = "white" {}
		
		_DetailMask( "Detail Mask", 2D ) = "white" {}

		_DetailAlbedoMap( "Detail Albedo x2", 2D ) = "grey" {}
		_DetailNormalMapScale( "Scale", Float ) = 1.0
		_DetailNormalMap( "Normal Map", 2D ) = "bump" {}

		g_tOverrideLightmap( "Override Lightmap", 2D ) = "white" {}

		[Enum(UV0,0,UV1,1)] _UVSec ( "UV Set for secondary textures", Float ) = 0

		[Toggle( S_RECEIVE_SHADOWS )] g_bReceiveShadows( "g_bReceiveShadows", Int ) = 1

		[Toggle( S_RENDER_BACKFACES )] g_bRenderBackfaces( "g_bRenderBackfaces", Int ) = 0

		[Toggle( S_WORLD_ALIGNED_TEXTURE )] g_bWorldAlignedTexture( "g_bWorldAlignedTexture", Int ) = 0
		g_vWorldAlignedTextureSize( "g_vWorldAlignedTextureSize", Vector ) = ( 1.0, 1.0, 1.0, 0.0 )
		g_vWorldAlignedTextureNormal( "g_vWorldAlignedTextureNormal", Vector ) = ( 0.0, 1.0, 0.0, 0.0 )
		g_vWorldAlignedTexturePosition( "g_vWorldAlignedTexturePosition", Vector ) = ( 0.0, 0.0, 0.0, 0.0 )
		[HideInInspector] g_vWorldAlignedNormalTangentU( "g_vWorldAlignedNormalTangentU", Vector ) = ( -1.0, 0.0, 0.0, 0.0)
		[HideInInspector] g_vWorldAlignedNormalTangentV( "g_vWorldAlignedNormalTangentV", Vector ) = ( 0.0, 0.0, 1.0, 0.0)

		[HideInInspector] _SpecularMode( "__specularmode", Int ) = 1
		[HideInInspector] _Cull ( "__cull", Int ) = 2

		// Blending state
		[HideInInspector] _Mode ( "__mode", Float ) = 0.0
		[HideInInspector] _SrcBlend ( "__src", Float ) = 1.0
		[HideInInspector] _DstBlend ( "__dst", Float ) = 0.0
		[HideInInspector] _ZWrite ( "__zw", Float ) = 1.0
		[HideInInspector] _FogMultiplier ( "__fogmult", Float ) = 1.0
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" "PerformanceChecks" = "False" }
		LOD 300

		//-------------------------------------------------------------------------------------------------------------------------------------------------------------
		// Base forward pass (directional light, emission, lightmaps, ...)
		//-------------------------------------------------------------------------------------------------------------------------------------------------------------
		Pass
		{
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" "PassFlags" = "OnlyDirectional" } // NOTE: "OnlyDirectional" prevents Unity from baking dynamic lights into SH terms at runtime

			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]
			Cull [_Cull]

			CGPROGRAM
				#pragma target 5.0
				#pragma only_renderers d3d11
				#pragma exclude_renderers gles

				//-------------------------------------------------------------------------------------------------------------------------------------------------------------
				#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
				#pragma shader_feature _NORMALMAP
				#pragma shader_feature _METALLICGLOSSMAP
				#pragma shader_feature _SPECGLOSSMAP
				#pragma shader_feature _EMISSION
				#pragma shader_feature _DETAIL_MULX2
				//#pragma shader_feature _PARALLAXMAP

				#pragma shader_feature S_SPECULAR_NONE S_SPECULAR_BLINNPHONG S_SPECULAR_METALLIC
				#pragma shader_feature S_UNLIT
				#pragma shader_feature S_OVERRIDE_LIGHTMAP
				#pragma shader_feature S_WORLD_ALIGNED_TEXTURE
				#pragma shader_feature S_RECEIVE_SHADOWS
				#pragma shader_feature S_OCCLUSION
				#pragma shader_feature S_RENDER_BACKFACES

				#pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
				#pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
				#pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON

				#pragma multi_compile _ MATRIX_PALETTE_SKINNING_1BONE
				#pragma multi_compile _ D_VALVE_FOG
				#pragma multi_compile _ D_VALVE_SHADOWING_POINT_LIGHTS

				#pragma skip_variants SHADOWS_SOFT

				#pragma vertex MainVs
				#pragma fragment MainPs

				// Dynamic combo skips (Static combo skips happen in ValveShaderGUI.cs in SetMaterialKeywords())
				#if ( S_UNLIT )
					#undef LIGHTMAP_OFF
					#define LIGHTMAP_OFF 1
					#undef LIGHTMAP_ON

					#undef DIRLIGHTMAP_OFF
					#define DIRLIGHTMAP_OFF 1
					#undef DIRLIGHTMAP_COMBINED
					#undef DIRLIGHTMAP_SEPARATE

					#undef DYNAMICLIGHTMAP_OFF
					#define DYNAMICLIGHTMAP_OFF 1
					#undef DYNAMICLIGHTMAP_ON
				#endif

				// Includes -------------------------------------------------------------------------------------------------------------------------------------------------
				#include "UnityCG.cginc"
				#include "UnityLightingCommon.cginc"
				#include "UnityStandardUtils.cginc"
				#include "UnityStandardInput.cginc"
				#include "vr_utils.cginc"
				#include "vr_lighting.cginc"
				#include "vr_matrix_palette_skinning.cginc"
				#include "vr_fog.cginc"

				// Structs --------------------------------------------------------------------------------------------------------------------------------------------------
				struct VS_INPUT
				{
					float4 vPositionOs : POSITION;
					float3 vNormalOs : NORMAL;
					float2 vTexCoord0 : TEXCOORD0;
					#if ( _DETAIL || S_OVERRIDE_LIGHTMAP || LIGHTMAP_ON )
						float2 vTexCoord1 : TEXCOORD1;
					#endif
					#if ( DYNAMICLIGHTMAP_ON || UNITY_PASS_META )
						float2 vTexCoord2 : TEXCOORD2;
					#endif

					#if ( _NORMALMAP )
						float4 vTangentUOs_flTangentVSign : TANGENT;
					#endif

					#if ( MATRIX_PALETTE_SKINNING )
						float4 vBoneIndices : COLOR;
					#endif
				};

				struct PS_INPUT
				{
					float4 vPositionPs : SV_Position;

					#if ( !S_UNLIT )
						float3 vPositionWs : TEXCOORD0;
						float3 vNormalWs : TEXCOORD1;
					#endif

					#if ( _DETAIL )
						float4 vTextureCoords : TEXCOORD2;
					#else
						float2 vTextureCoords : TEXCOORD2;
					#endif

					#if ( S_OVERRIDE_LIGHTMAP || LIGHTMAP_ON || DYNAMICLIGHTMAP_ON )
						#if ( DYNAMICLIGHTMAP_ON )
							centroid float4 vLightmapUV : TEXCOORD3;
						#else
							centroid float2 vLightmapUV : TEXCOORD3;
						#endif
					#endif

					#if ( _NORMALMAP )
						float3 vTangentUWs : TEXCOORD4;
						float3 vTangentVWs : TEXCOORD5;
					#endif

					#if ( D_VALVE_FOG )
						float2 vFogCoords : TEXCOORD6;
					#endif
				};

				float g_flValveGlobalVertexScale = 1.0; // Used to "hide" all valve materials for debugging

				// World-aligned texture
				float3 g_vWorldAlignedTextureSize = float3( 1.0, 1.0, 1.0 );
				float3 g_vWorldAlignedNormalTangentU = float3( -1.0, 0.0, 0.0 );
				float3 g_vWorldAlignedNormalTangentV = float3( 0.0, 0.0, 1.0 );
				float3 g_vWorldAlignedTexturePosition = float3( 0.0, 0.0, 0.0 );

				// MainVs ---------------------------------------------------------------------------------------------------------------------------------------------------
				PS_INPUT MainVs( VS_INPUT i )
				{
					PS_INPUT o = ( PS_INPUT )0;

					#if ( MATRIX_PALETTE_SKINNING )
					{
						#if ( _NORMALMAP )
						{
							MatrixPaletteSkinning( i.vPositionOs.xyzw, i.vNormalOs.xyz, i.vTangentUOs_flTangentVSign.xyz, i.vBoneIndices.xyzw );
						}
						#else
						{
							MatrixPaletteSkinning( i.vPositionOs.xyzw, i.vNormalOs.xyz, i.vBoneIndices.xyzw );
						}
						#endif
					}
					#endif

					// Position
					i.vPositionOs.xyzw *= g_flValveGlobalVertexScale; // Used to "hide" all valve materials for debugging
					float3 vPositionWs = mul( unity_ObjectToWorld, i.vPositionOs.xyzw ).xyz;
					#if ( !S_UNLIT )
					{
						o.vPositionWs.xyz = vPositionWs.xyz;
					}
					#endif
					o.vPositionPs.xyzw = mul( UNITY_MATRIX_MVP, i.vPositionOs.xyzw );

					// Normal
					float3 vNormalWs = UnityObjectToWorldNormal( i.vNormalOs.xyz );
					#if ( !S_UNLIT )
					{
						o.vNormalWs.xyz = vNormalWs.xyz;
					}
					#endif

					#if ( _NORMALMAP )
					{
						// TangentU and TangentV
						float3 vTangentUWs = UnityObjectToWorldDir( i.vTangentUOs_flTangentVSign.xyz ); // Transform tangentU into world space
						//vTangentUWs.xyz = normalize( vTangentUWs.xyz - ( vNormalWs.xyz * dot( vTangentUWs.xyz, vNormalWs.xyz ) ) ); // Force tangentU perpendicular to normal and normalize

						o.vTangentUWs.xyz = vTangentUWs.xyz;
						o.vTangentVWs.xyz = cross( vNormalWs.xyz, vTangentUWs.xyz ) * i.vTangentUOs_flTangentVSign.w;
					}
					#endif

					#if ( S_WORLD_ALIGNED_TEXTURE )
					{
						float3 vTexturePositionScaledWs = ( vPositionWs.xyz - g_vWorldAlignedTexturePosition.xyz ) / g_vWorldAlignedTextureSize.xyz;
						o.vTextureCoords.x = dot( vTexturePositionScaledWs.xyz, g_vWorldAlignedNormalTangentU.xyz );
						o.vTextureCoords.y = dot( vTexturePositionScaledWs.xyz, g_vWorldAlignedNormalTangentV.xyz );
						#if ( _DETAIL )
						{
							o.vTextureCoords.zw = TRANSFORM_TEX( o.vTextureCoords.xy, _DetailAlbedoMap );
						}
						#endif
					}
					#else
					{
						// Texture coords (Copied from Unity's TexCoords() helper function)
						o.vTextureCoords.xy = TRANSFORM_TEX( i.vTexCoord0, _MainTex );
						#if ( _DETAIL )
						{
							o.vTextureCoords.zw = TRANSFORM_TEX( ( ( _UVSec == 0 ) ? i.vTexCoord0 : i.vTexCoord1 ), _DetailAlbedoMap );
						}
						#endif
					}
					#endif

					// Indirect lighting uv's or light probe
					#if ( S_OVERRIDE_LIGHTMAP )
					{
						o.vLightmapUV.xy = i.vTexCoord1.xy;
					}
					#elif ( LIGHTMAP_ON )
					{
						// Static lightmaps
						o.vLightmapUV.xy = i.vTexCoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
					}
					#endif

					#if ( DYNAMICLIGHTMAP_ON )
					{
						o.vLightmapUV.zw = i.vTexCoord2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
					}
					#endif

					#if ( D_VALVE_FOG )
					{
						o.vFogCoords.xy = CalculateFogCoords( vPositionWs.xyz );
					}
					#endif

					return o;
				}

				// MainPs ---------------------------------------------------------------------------------------------------------------------------------------------------
				#define g_vColorTint _Color
				#define g_tColor _MainTex
				#define g_tNormalMap _BumpMap
				#define g_flBumpScale _BumpScale
				#define g_vReflectance _SpecColor
				#define g_tReflectanceGloss _SpecGlossMap
				#define g_flGlossScale _Glossiness
				#define g_tDetailAlbedo _DetailAlbedoMap
				#define g_tDetailNormal _DetailNormalMap
				#define g_flDetailNormalScale _DetailNormalMapScale

				float g_flReflectanceScale = 1.0;
				float g_flReflectanceBias = 0.0;

				float _OcclusionStrengthDirectDiffuse = 1.0;
				float _OcclusionStrengthDirectSpecular = 1.0;
				float _OcclusionStrengthIndirectDiffuse = 1.0;
				float _OcclusionStrengthIndirectSpecular = 1.0;

				float _FogMultiplier = 1.0;

				struct PS_OUTPUT
				{
					float4 vColor : SV_Target0;
				};

				PS_OUTPUT MainPs( PS_INPUT i
					#if ( S_RENDER_BACKFACES )
						, bool bIsFrontFace : SV_IsFrontFace
					#endif
					)
				{
					PS_OUTPUT o = ( PS_OUTPUT )0;

					//-----------------------------------------------------------//
					// Negate the world normal if we are rendering the back face //
					//-----------------------------------------------------------//
					#if ( S_RENDER_BACKFACES )
					{
						i.vNormalWs.xyz *= ( bIsFrontFace ? 1.0 : -1.0 );
					}
					#endif

					//--------//
					// Albedo //
					//--------//
					float4 vAlbedoTexel = tex2D( g_tColor, i.vTextureCoords.xy ) * g_vColorTint.rgba;
					float3 vAlbedo = vAlbedoTexel.rgb;

					// Apply detail to albedo
					#if ( _DETAIL )
					{
						float flDetailMask = DetailMask( i.vTextureCoords.xy );
						float3 vDetailAlbedo = tex2D( g_tDetailAlbedo, i.vTextureCoords.zw ).rgb;
						#if ( _DETAIL_MULX2 )
							vAlbedo.rgb *= LerpWhiteTo( vDetailAlbedo.rgb * unity_ColorSpaceDouble.rgb, flDetailMask );
						#elif ( _DETAIL_MUL )
							vAlbedo.rgb *= LerpWhiteTo( vDetailAlbedo.rgb, flDetailMask );
						#elif ( _DETAIL_ADD )
							vAlbedo.rgb += vDetailAlbedo.rgb * flDetailMask;
						#elif ( _DETAIL_LERP )
							vAlbedo.rgb = lerp( vAlbedo.rgb, vDetailAlbedo.rgb, flDetailMask );
						#endif
					}
					#endif

					//--------------//
					// Translucency //
					//--------------//
					#if ( _ALPHATEST_ON )
					{
						clip( vAlbedoTexel.a - _Cutoff );
					}
					#endif

					#if ( _ALPHAPREMULTIPLY_ON )
					{
						vAlbedo.rgb *= vAlbedoTexel.a;
					}
					#endif

					#if ( _ALPHABLEND_ON || _ALPHAPREMULTIPLY_ON )
					{
						o.vColor.a = vAlbedoTexel.a;
					}
					#else
					{
						o.vColor.a = 1.0;
					}
					#endif

					//---------------//
					// Tangent Space //
					//---------------//
					float3 vTangentUWs = float3( 1.0, 0.0, 0.0 );
					float3 vTangentVWs = float3( 0.0, 1.0, 0.0 );
					#if ( _NORMALMAP )
					{
						vTangentUWs.xyz = i.vTangentUWs.xyz;
						vTangentVWs.xyz = i.vTangentVWs.xyz;
					}
					#endif

					//--------//
					// Normal //
					//--------//
					float3 vGeometricNormalWs = float3( 0.0, 0.0, 1.0 );
					#if ( !S_UNLIT )
					{
						i.vNormalWs.xyz = normalize( i.vNormalWs.xyz );
						vGeometricNormalWs.xyz = i.vNormalWs.xyz;
					}
					#endif

					float3 vNormalWs = vGeometricNormalWs.xyz;
					float3 vNormalTs = float3( 0.0, 0.0, 1.0 );
					#if ( _NORMALMAP )
					{
						vNormalTs.xyz = UnpackScaleNormal( tex2D( g_tNormalMap, i.vTextureCoords.xy ), g_flBumpScale );
						//vNormalTs.y = -vNormalTs.y;

						// Apply detail to tangent normal
						#if ( _DETAIL )
						{
							float flDetailMask = DetailMask( i.vTextureCoords.xy );
							float3 vDetailNormalTs = UnpackScaleNormal( tex2D( g_tDetailNormal, i.vTextureCoords.zw ), g_flDetailNormalScale );
							#if ( _DETAIL_LERP )
							{
								vNormalTs.xyz = lerp( vNormalTs.xyz, vDetailNormalTs.xyz, flDetailMask );
							}
							#else				
							{
								vNormalTs.xyz = lerp( vNormalTs.xyz, BlendNormals( vNormalTs.xyz, vDetailNormalTs.xyz ), flDetailMask );
							}
							#endif
						}
						#endif

						// Convert to world space
						vNormalWs.xyz = Vec3TsToWsNormalized( vNormalTs.xyz, vGeometricNormalWs.xyz, vTangentUWs.xyz, vTangentVWs.xyz );
					}
					#endif

					//-----------//
					// Roughness //
					//-----------//
					float2 vRoughness = float2( 0.6, 0.6 );// vNormalTexel.rb;
					//#if ( S_HIGH_QUALITY_GLOSS )
					//{
					//	float4 vGlossTexel = Tex2D( g_tGloss, i.vTextureCoords.xy );
					//	vRoughness.xy += vGlossTexel.ag;
					//}
					//#endif

					// Reflectance and gloss
					float3 vReflectance = float3( 0.0, 0.0, 0.0 );
					float flGloss = 0.0;
					#if ( S_SPECULAR_METALLIC )
					{
						float2 vMetallicGloss;// = MetallicGloss( i.vTextureCoords.xy );
						#ifdef _METALLICGLOSSMAP
							vMetallicGloss.xy = tex2D(_MetallicGlossMap, i.vTextureCoords.xy).ra;
						#else
							vMetallicGloss.xy = half2(_Metallic, _Glossiness);
						#endif

						float flOneMinusReflectivity;
						float3 vSpecColor;
						float3 diffColor = DiffuseAndSpecularFromMetallic( vAlbedo.rgb, vMetallicGloss.x, /*out*/ vSpecColor, /*out*/ flOneMinusReflectivity);
						vAlbedo.rgb = diffColor.rgb;

						vReflectance.rgb = vSpecColor.rgb;
						flGloss = vMetallicGloss.y;
					}
					#elif ( S_SPECULAR_BLINNPHONG )
					{
						float4 vReflectanceGloss; // = SpecularGloss( i.vTextureCoords.xy );
						#ifdef _SPECGLOSSMAP
							vReflectanceGloss.rgba = tex2D(_SpecGlossMap, i.vTextureCoords.xy);
						#else
							vReflectanceGloss.rgba = float4(_SpecColor.rgb, _Glossiness);
						#endif

						vReflectanceGloss.rgb = ( vReflectanceGloss.rgb * g_flReflectanceScale.xxx ) + g_flReflectanceBias.xxx;
						vReflectance.rgb = vReflectanceGloss.rgb;
						flGloss = vReflectanceGloss.a;
					}
					#endif

					vRoughness.xy = ( 1.0 - flGloss ).xx;
					#if ( !S_SPECULAR_NONE )
					{
						vRoughness.xy = AdjustRoughnessByGeometricNormal( vRoughness.xy, vGeometricNormalWs.xyz );
					}
					#endif

					//----------//
					// Lighting //
					//----------//
					LightingTerms_t lightingTerms;
					lightingTerms.vDiffuse.rgb = float3( 1.0, 1.0, 1.0 );
					lightingTerms.vSpecular.rgb = float3( 0.0, 0.0, 0.0 );
					lightingTerms.vIndirectDiffuse.rgb = float3( 0.0, 0.0, 0.0 );
					lightingTerms.vIndirectSpecular.rgb = float3( 0.0, 0.0, 0.0 );
					lightingTerms.vTransmissiveSunlight.rgb = float3( 0.0, 0.0, 0.0 );

					float flFresnelExponent = 5.0;
					float flMetalness = 0.0f;

					#if ( !S_UNLIT )
					{
						float4 vLightmapUV = float4( 0.0, 0.0, 0.0, 0.0 );
						#if ( S_OVERRIDE_LIGHTMAP || LIGHTMAP_ON || DYNAMICLIGHTMAP_ON )
						{
							vLightmapUV.xy = i.vLightmapUV.xy;
							#if ( DYNAMICLIGHTMAP_ON )
							{
								vLightmapUV.zw = i.vLightmapUV.zw;
							}
							#endif
						}
						#endif

						// Compute lighting
						lightingTerms = ComputeLighting( i.vPositionWs.xyz, vNormalWs.xyz, vTangentUWs.xyz, vTangentVWs.xyz, vRoughness.xy, vReflectance.rgb, flFresnelExponent, vLightmapUV.xyzw );

						#if ( S_OCCLUSION )
						{
							float flOcclusion = tex2D( _OcclusionMap, i.vTextureCoords.xy ).g;
							lightingTerms.vDiffuse.rgb *= LerpOneTo( flOcclusion, _OcclusionStrength * _OcclusionStrengthDirectDiffuse );
							lightingTerms.vSpecular.rgb *= LerpOneTo( flOcclusion, _OcclusionStrength * _OcclusionStrengthDirectSpecular );
							lightingTerms.vIndirectDiffuse.rgb *= LerpOneTo( flOcclusion, _OcclusionStrength * _OcclusionStrengthIndirectDiffuse );
							lightingTerms.vIndirectSpecular.rgb *= LerpOneTo( flOcclusion, _OcclusionStrength * _OcclusionStrengthIndirectSpecular );
						}
						#endif
					}
					#endif

					// Diffuse
					o.vColor.rgb = ( lightingTerms.vDiffuse.rgb + lightingTerms.vIndirectDiffuse.rgb ) * vAlbedo.rgb;

					// Specular
					#if ( !S_SPECULAR_NONE )
					{
						o.vColor.rgb += lightingTerms.vSpecular.rgb;
					}
					#endif
					o.vColor.rgb += lightingTerms.vIndirectSpecular.rgb; // Indirect specular applies its own fresnel in the forward lighting header file

					// Emission - Unity just adds the emissive term at the end instead of adding it to the diffuse lighting term. Artists may want both options.
					float3 vEmission = Emission( i.vTextureCoords.xy );
					o.vColor.rgb += vEmission.rgb;

					// Fog
					#if ( D_VALVE_FOG )
					{
						o.vColor.rgb = ApplyFog( o.vColor.rgb, i.vFogCoords.xy, _FogMultiplier );
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

	CustomEditor "ValveShaderGUI"
}
