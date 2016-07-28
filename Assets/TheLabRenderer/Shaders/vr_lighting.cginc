// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================

#ifndef VALVE_VR_LIGHTING_INCLUDED
#define VALVE_VR_LIGHTING_INCLUDED

#include "UnityCG.cginc"
#include "UnityStandardBRDF.cginc"

#define Tex2DLevel( name, uv, flLevel ) name.SampleLevel( sampler##name, ( uv ).xy, flLevel )
#define Tex2DLevelFromSampler( texturename, samplername, uv, flLevel ) texturename.SampleLevel( sampler##samplername, ( uv ).xy, flLevel )

//---------------------------------------------------------------------------------------------------------------------------------------------------------
#define MAX_LIGHTS 18
CBUFFER_START( ValveVrLighting )
	int g_nNumLights;
	bool g_bIndirectLightmaps = false;

	float4 g_vLightColor[ MAX_LIGHTS ];
	float4 g_vLightPosition_flInvRadius[ MAX_LIGHTS ];
	float4 g_vLightDirection[ MAX_LIGHTS ];
	float4 g_vLightShadowIndex_vLightParams[ MAX_LIGHTS ]; // x = Shadow index, y = Light cookie index, z = Diffuse enabled, w = Specular enabled
	float4 g_vLightFalloffParams[ MAX_LIGHTS ]; // x = Linear falloff, y = Quadratic falloff, z = Radius squared for culling
	float4 g_vSpotLightInnerOuterConeCosines[ MAX_LIGHTS ];

	float4 g_vShadowMinMaxUv[ MAX_LIGHTS ];
	float4x4 g_matWorldToShadow[ MAX_LIGHTS ];
	float4 g_vShadow3x3PCFTerms0;
	float4 g_vShadow3x3PCFTerms1;
	float4 g_vShadow3x3PCFTerms2;
	float4 g_vShadow3x3PCFTerms3;

	float4x4 g_matWorldToLightCookie[ MAX_LIGHTS ];
CBUFFER_END

// Override lightmap
sampler2D g_tOverrideLightmap;
uniform float3 g_vOverrideLightmapScale;

float g_flCubeMapScalar = 1.0;

float g_flReflectanceMin = 0.0;
float g_flReflectanceMax = 1.0;

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
struct LightingTerms_t
{
	float3 vDiffuse;
	float3 vSpecular;
	float3 vIndirectDiffuse;
	float3 vIndirectSpecular;
	float3 vTransmissiveSunlight;
};

//---------------------------------------------------------------------------------------------------------------------------------------------------------
float CalculateGeometricRoughnessFactor( float3 vGeometricNormalWs )
{
	float3 vNormalWsDdx = ddx( vGeometricNormalWs.xyz );
	float3 vNormalWsDdy = ddy( vGeometricNormalWs.xyz );
	float flGeometricRoughnessFactor = pow( saturate( max( dot( vNormalWsDdx.xyz, vNormalWsDdx.xyz ), dot( vNormalWsDdy.xyz, vNormalWsDdy.xyz ) ) ), 0.333 );
	return flGeometricRoughnessFactor;
}

float2 AdjustRoughnessByGeometricNormal( float2 vRoughness, float3 vGeometricNormalWs )
{
	float flGeometricRoughnessFactor = CalculateGeometricRoughnessFactor( vGeometricNormalWs.xyz );

	//if ( Blink( 1.0 ) )
	vRoughness.xy = max( vRoughness.xy, flGeometricRoughnessFactor.xx );
	return vRoughness.xy;
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------
void RoughnessEllipseToScaleAndExp( float2 vRoughness, out float2 o_vDiffuseExponentOut, out float2 o_vSpecularExponentOut, out float2 o_vSpecularScaleOut )
{
	o_vDiffuseExponentOut.xy = ( ( 1.0 - vRoughness.xy ) * 0.8 ) + 0.6; // 0.8 and 0.6 are magic numbers
	o_vSpecularExponentOut.xy = exp2( pow( float2( 1.0, 1.0 ) - vRoughness.xy, float2( 1.5, 1.5 ) ) * float2( 14.0, 14.0 ) ); // Outputs 1-16384
	o_vSpecularScaleOut.xy = 1.0 - saturate( vRoughness.xy * 0.5 ); // This is an energy conserving scalar for the roughness exponent.
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------
// Used for ( N.H^k ) * ( N.L )
//---------------------------------------------------------------------------------------------------------------------------------------------------------
float BlinnPhongModifiedNormalizationFactor( float k )
{
	float flNumer = ( k + 2.0 ) * ( k + 4.0 );
	float flDenom = 8 * ( exp2( -k * 0.5 ) + k );
	return flNumer / flDenom;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
float DistanceFalloff( float flDistToLightSq, float flLightInvRadius, float2 vFalloffParams )
{
	// AV - My approximation to Unity's falloff function (I'll experiment with putting this into a texture later)
	return lerp( 1.0, ( 1.0 - pow( flDistToLightSq * flLightInvRadius * flLightInvRadius, 0.175 ) ), vFalloffParams.x );

	// AV - This is the VR Aperture Demo falloff function
	//flDistToLightSq = max( flDistToLightSq, 8.0f ); // Can't be inside the light source (assuming radius^2 == 8.0f)
	//
	//float2 vInvRadiusAndInvRadiusSq = float2( flLightInvRadius, flLightInvRadius * flLightInvRadius );
	//float2 vLightDistAndLightDistSq = float2( sqrt( flDistToLightSq ), flDistToLightSq );
	//
	//float flTruncation = dot( vFalloffParams.xy, vInvRadiusAndInvRadiusSq.xy ); // Constant amount to subtract to ensure that the light is zero past the light radius
	//float flFalloff = dot( vFalloffParams.xy, vLightDistAndLightDistSq.xy );
	//
	//return saturate( ( 1.0f / flFalloff ) - flTruncation );
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------
// Anisotropic diffuse and specular lighting based on 2D tangent-space axis-aligned roughness
//---------------------------------------------------------------------------------------------------------------------------------------------------------
float4 ComputeDiffuseAndSpecularTerms( bool bDiffuse, bool bSpecular,
									   float3 vNormalWs, float3 vEllipseUWs, float3 vEllipseVWs, float3 vPositionToLightDirWs, float3 vPositionToCameraDirWs,
									   float2 vDiffuseExponent, float2 vSpecularExponent, float2 vSpecularScale, float3 vReflectance, float flFresnelExponent )
{
	float flNDotL = ClampToPositive( dot( vNormalWs.xyz, vPositionToLightDirWs.xyz ) );

	// Diffuse
	float flDiffuseTerm = 0.0;
	if ( bDiffuse )
	{
		/* Disabling anisotropic diffuse until we have a need for it. Isotropic diffuse should be enough.
		// Project light vector onto each tangent plane
		float3 vDiffuseNormalX = vPositionToLightDirWs.xyz - ( vEllipseUWs.xyz * dot( vPositionToLightDirWs.xyz, vEllipseUWs.xyz ) ); // Not normalized on purpose
		float3 vDiffuseNormalY = vPositionToLightDirWs.xyz - ( vEllipseVWs.xyz * dot( vPositionToLightDirWs.xyz, vEllipseVWs.xyz ) ); // Not normalized on purpose

		float flNDotLX = ClampToPositive( dot( vDiffuseNormalX.xyz, vPositionToLightDirWs.xyz ) );
		flNDotLX = pow( flNDotLX, vDiffuseExponent.x * 0.5 );

		float flNDotLY = ClampToPositive( dot( vDiffuseNormalY.xyz, vPositionToLightDirWs.xyz ) );
		flNDotLY = pow( flNDotLY, vDiffuseExponent.y * 0.5 );

		flDiffuseTerm = flNDotLX * flNDotLY;
		flDiffuseTerm *= ( ( vDiffuseExponent.x * 0.5 + vDiffuseExponent.y * 0.5 ) + 1.0 ) * 0.5;
		flDiffuseTerm *= flNDotL;
		//*/

		float flDiffuseExponent = ( vDiffuseExponent.x + vDiffuseExponent.y ) * 0.5;
		flDiffuseTerm = pow( flNDotL, flDiffuseExponent ) * ( ( flDiffuseExponent + 1.0 ) * 0.5 );
	}

	// Specular
	float3 vSpecularTerm = float3( 0.0, 0.0, 0.0 );
	[branch] if ( bSpecular )
	{
		float3 vHalfAngleDirWs = normalize( vPositionToLightDirWs.xyz + vPositionToCameraDirWs.xyz );

		float flSpecularTerm = 0.0;
		#if ( S_ANISOTROPIC_GLOSS ) // Adds 34 asm instructions compared to isotropic spec in #else below
		{
			float3 vSpecularNormalX = vHalfAngleDirWs.xyz - ( vEllipseUWs.xyz * dot( vHalfAngleDirWs.xyz, vEllipseUWs.xyz ) ); // Not normalized on purpose
			float3 vSpecularNormalY = vHalfAngleDirWs.xyz - ( vEllipseVWs.xyz * dot( vHalfAngleDirWs.xyz, vEllipseVWs.xyz ) ); // Not normalized on purpose

			float flNDotHX = ClampToPositive( dot( vSpecularNormalX.xyz, vHalfAngleDirWs.xyz ) );
			float flNDotHkX = pow( flNDotHX, vSpecularExponent.x * 0.5 );
			flNDotHkX *= vSpecularScale.x;

			float flNDotHY = ClampToPositive( dot( vSpecularNormalY.xyz, vHalfAngleDirWs.xyz ) );
			float flNDotHkY = pow( flNDotHY, vSpecularExponent.y * 0.5 );
			flNDotHkY *= vSpecularScale.y;

			flSpecularTerm = flNDotHkX * flNDotHkY;
		}
		#else
		{
			float flNDotH = saturate( dot( vNormalWs.xyz, vHalfAngleDirWs.xyz ) );
			float flNDotHk = pow( flNDotH, dot( vSpecularExponent.xy, float2( 0.5, 0.5 ) ) );
			flNDotHk *= dot( vSpecularScale.xy, float2( 0.33333, 0.33333 ) ); // The 0.33333 is to match the spec of the aniso algorithm above with isotropic roughness values
			flSpecularTerm = flNDotHk;
		}
		#endif

		flSpecularTerm *= flNDotL; // This makes it modified Blinn-Phong
		flSpecularTerm *= BlinnPhongModifiedNormalizationFactor( vSpecularExponent.x * 0.5 + vSpecularExponent.y * 0.5 );

		float flLDotH = ClampToPositive( dot( vPositionToLightDirWs.xyz, vHalfAngleDirWs.xyz ) );
		float3 vMaxReflectance = vReflectance.rgb / ( Luminance( vReflectance.rgb ) + 0.0001 );
		float3 vFresnel = lerp( vReflectance.rgb, vMaxReflectance.rgb, pow( 1.0 - flLDotH, flFresnelExponent ) );
		vSpecularTerm.rgb = flSpecularTerm * vFresnel.rgb;
	}

	return float4( flDiffuseTerm, vSpecularTerm.rgb );
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
// Filter weights: 20 33 20
//                 33 55 33
//                 20 33 20
//-------------------------------------------------------------------------------------------------------------------------------------------------------------
#define VALVE_DECLARE_SHADOWMAP( tex ) Texture2D tex; SamplerComparisonState sampler##tex
#define VALVE_SAMPLE_SHADOW( tex, coord ) tex.SampleCmpLevelZero( sampler##tex, (coord).xy, (coord).z )

VALVE_DECLARE_SHADOWMAP( g_tShadowBuffer );

float2 ClampShadowUv( float2 vUv, float4 vShadowMinMaxUv )
{
	#if ( D_VALVE_SHADOWING_POINT_LIGHTS )
	{
		vUv.xy = max( vUv.xy, vShadowMinMaxUv.xy );
		vUv.xy = min( vUv.xy, vShadowMinMaxUv.zw );
	}
	#endif
	return vUv.xy;
}

float ComputeShadow_PCF_3x3_Gaussian( float3 vPositionWs, float4x4 matWorldToShadow, float4 vShadowMinMaxUv )
{
	float4 vPositionTextureSpace = mul( float4( vPositionWs.xyz, 1.0 ), matWorldToShadow );
	vPositionTextureSpace.xyz /= vPositionTextureSpace.w;

	float2 shadowMapCenter = vPositionTextureSpace.xy;

	//if ( ( frac( shadowMapCenter.x ) != shadowMapCenter.x ) || ( frac( shadowMapCenter.y ) != shadowMapCenter.y ) )
	if ( ( shadowMapCenter.x < 0.0f ) || ( shadowMapCenter.x > 1.0f ) || ( shadowMapCenter.y < 0.0f ) || ( shadowMapCenter.y > 1.0f ) )
		return 1.0f;

	float objDepth = ( vPositionTextureSpace.z );

	/* // Depth texture visualization
	if ( 1 )
	{
		#define NUM_SAMPLES 128.0
		float flSum = 0.0;
		for ( int j = 0; j < NUM_SAMPLES; j++ )
		{
			flSum += ( 1.0 / NUM_SAMPLES ) * ( VALVE_SAMPLE_SHADOW( g_tShadowBuffer, float3( shadowMapCenter.xy, j / NUM_SAMPLES ) ).r );
		}
		return flSum;
	}
	//*/

	float4 v20Taps;
	v20Taps.x = VALVE_SAMPLE_SHADOW( g_tShadowBuffer, float3( ClampShadowUv( shadowMapCenter.xy + g_vShadow3x3PCFTerms1.xy, vShadowMinMaxUv ), objDepth ) ).x; //  1  1
	v20Taps.y = VALVE_SAMPLE_SHADOW( g_tShadowBuffer, float3( ClampShadowUv( shadowMapCenter.xy + g_vShadow3x3PCFTerms1.zy, vShadowMinMaxUv ), objDepth ) ).x; // -1  1
	v20Taps.z = VALVE_SAMPLE_SHADOW( g_tShadowBuffer, float3( ClampShadowUv( shadowMapCenter.xy + g_vShadow3x3PCFTerms1.xw, vShadowMinMaxUv ), objDepth ) ).x; //  1 -1
	v20Taps.w = VALVE_SAMPLE_SHADOW( g_tShadowBuffer, float3( ClampShadowUv( shadowMapCenter.xy + g_vShadow3x3PCFTerms1.zw, vShadowMinMaxUv ), objDepth ) ).x; // -1 -1
	float flSum = dot( v20Taps.xyzw, float4( 0.25, 0.25, 0.25, 0.25 ) );
	if ( ( flSum == 0.0 ) || ( flSum == 1.0 ) )
		return flSum;
	flSum *= g_vShadow3x3PCFTerms0.x * 4.0;

	float4 v33Taps;
	v33Taps.x = VALVE_SAMPLE_SHADOW( g_tShadowBuffer, float3( ClampShadowUv( shadowMapCenter.xy + g_vShadow3x3PCFTerms2.xz, vShadowMinMaxUv ), objDepth ) ).x; //  1  0
	v33Taps.y = VALVE_SAMPLE_SHADOW( g_tShadowBuffer, float3( ClampShadowUv( shadowMapCenter.xy + g_vShadow3x3PCFTerms3.xz, vShadowMinMaxUv ), objDepth ) ).x; // -1  0
	v33Taps.z = VALVE_SAMPLE_SHADOW( g_tShadowBuffer, float3( ClampShadowUv( shadowMapCenter.xy + g_vShadow3x3PCFTerms3.zy, vShadowMinMaxUv ), objDepth ) ).x; //  0 -1
	v33Taps.w = VALVE_SAMPLE_SHADOW( g_tShadowBuffer, float3( ClampShadowUv( shadowMapCenter.xy + g_vShadow3x3PCFTerms2.zy, vShadowMinMaxUv ), objDepth ) ).x; //  0  1
	flSum += dot( v33Taps.xyzw, g_vShadow3x3PCFTerms0.yyyy );

	flSum += VALVE_SAMPLE_SHADOW( g_tShadowBuffer, float3( ClampShadowUv( shadowMapCenter.xy, vShadowMinMaxUv ), objDepth ) ).x * g_vShadow3x3PCFTerms0.z;

	return flSum;
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------
float3 ComputeOverrideLightmap( float2 vLightmapUV )
{
	float4 vLightmapTexel = tex2D( g_tOverrideLightmap, vLightmapUV.xy );

	// This path looks over-saturated
	//return g_vOverrideLightmapScale * ( unity_Lightmap_HDR.x * pow( vLightmapTexel.a, unity_Lightmap_HDR.y ) ) * vLightmapTexel.rgb;

	// This path looks less broken
	return g_vOverrideLightmapScale * ( unity_Lightmap_HDR.x * vLightmapTexel.a ) * sqrt( vLightmapTexel.rgb );
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------
LightingTerms_t ComputeLighting( float3 vPositionWs, float3 vNormalWs, float3 vTangentUWs, float3 vTangentVWs, float2 vRoughness,
								 float3 vReflectance, float flFresnelExponent, float4 vLightmapUV )
{
	LightingTerms_t o;
	o.vDiffuse = float3( 0.0, 0.0, 0.0 );
	o.vSpecular = float3( 0.0, 0.0, 0.0 );
	o.vIndirectDiffuse = float3( 0.0, 0.0, 0.0 );
	o.vIndirectSpecular = float3( 0.0, 0.0, 0.0 );
	o.vTransmissiveSunlight = float3( 0.0, 0.0, 0.0 );

	// Convert roughness to scale and exp
	float2 vDiffuseExponent;
	float2 vSpecularExponent;
	float2 vSpecularScale;
	RoughnessEllipseToScaleAndExp( vRoughness.xy, vDiffuseExponent.xy, vSpecularExponent.xy, vSpecularScale.xy );

	float3 vPositionToCameraDirWs = CalculatePositionToCameraDirWs( vPositionWs.xyz );

	// Compute tangent frame relative to per-pixel normal
	float3 vEllipseUWs = normalize( cross( vTangentVWs.xyz, vNormalWs.xyz ) );
	float3 vEllipseVWs = normalize( cross( vNormalWs.xyz, vTangentUWs.xyz ) );

	//-------------------------------------//
	// Point, spot, and directional lights //
	//-------------------------------------//
	int nNumLightsUsed = 0;
	[ loop ] for ( int i = 0; i < g_nNumLights; i++ )
	{
		float3 vPositionToLightRayWs = g_vLightPosition_flInvRadius[ i ].xyz - vPositionWs.xyz;
		float flDistToLightSq = dot( vPositionToLightRayWs.xyz, vPositionToLightRayWs.xyz );
		if ( flDistToLightSq > g_vLightFalloffParams[ i ].z ) // .z stores radius squared of light
		{
			// Outside light range
			continue;
		}

		if ( dot( vNormalWs.xyz, vPositionToLightRayWs.xyz ) <= 0.0 )
		{
			// Backface cull pixel to this light
			continue;
		}

		float3 vPositionToLightDirWs = normalize( vPositionToLightRayWs.xyz );
		float flOuterConeCos = g_vSpotLightInnerOuterConeCosines[ i ].y;
		float flTemp = dot( vPositionToLightDirWs.xyz, -g_vLightDirection[ i ].xyz ) - flOuterConeCos;
		if ( flTemp <= 0.0 )
		{
			// Outside spotlight cone
			continue;
		}
		float3 vSpotAtten = saturate( flTemp * g_vSpotLightInnerOuterConeCosines[ i ].z ).xxx;

		nNumLightsUsed++;

		//[branch] if ( g_vLightShadowIndex_vLightParams[ i ].y != 0 ) // If has a light cookie
		//{
		//	// Light cookie
		//	float4 vPositionTextureSpace = mul( float4( vPositionWs.xyz, 1.0 ), g_matWorldToLightCookie[ i ] );
		//	vPositionTextureSpace.xyz /= vPositionTextureSpace.w;
		//	vSpotAtten.rgb = Tex3DLevel( g_tVrLightCookieTexture, vPositionTextureSpace.xyz, 0.0 ).rgb;
		//}

		float flLightFalloff = DistanceFalloff( flDistToLightSq, g_vLightPosition_flInvRadius[ i ].w, g_vLightFalloffParams[ i ].xy );

		float flShadowScalar = 1.0;
		#if ( S_RECEIVE_SHADOWS )
		{
			if ( g_vLightShadowIndex_vLightParams[ i ].x != 0.0 ) // If light casts shadows
			{
				#if ( D_VALVE_SHADOWING_POINT_LIGHTS )
				{
					if ( g_vLightShadowIndex_vLightParams[ i ].y == 2.0 ) // If light is a point light's fake spotlight
					{
						// Cull pixels outside the 90 degree frustum
						float4 vPositionTextureSpace = mul( float4( vPositionWs.xyz, 1.0 ), g_matWorldToLightCookie[ i ] );
						if ( ( vPositionTextureSpace.x < 0.0f ) || ( vPositionTextureSpace.y < 0.0f ) || ( vPositionTextureSpace.x > vPositionTextureSpace.w ) || ( vPositionTextureSpace.y > vPositionTextureSpace.w ) )
							continue;
					}
				}
				#endif

				flShadowScalar = ComputeShadow_PCF_3x3_Gaussian( vPositionWs.xyz, g_matWorldToShadow[ i ], g_vShadowMinMaxUv[ i ] );
				if ( flShadowScalar <= 0.0 )
					continue;
			}
		}
		#endif

		float4 vLightingTerms = ComputeDiffuseAndSpecularTerms( g_vLightShadowIndex_vLightParams[ i ].z != 0.0, g_vLightShadowIndex_vLightParams[ i ].w != 0.0,
																vNormalWs.xyz, vEllipseUWs.xyz, vEllipseVWs.xyz,
																vPositionToLightDirWs.xyz, vPositionToCameraDirWs.xyz,
																vDiffuseExponent.xy, vSpecularExponent.xy, vSpecularScale.xy, vReflectance.rgb, flFresnelExponent );

		float3 vLightColor = g_vLightColor[ i ].rgb;
		float3 vLightMask = vLightColor.rgb * flShadowScalar * flLightFalloff * vSpotAtten.rgb;
		o.vDiffuse.rgb += vLightingTerms.xxx * vLightMask.rgb;
		o.vSpecular.rgb += vLightingTerms.yzw * vLightMask.rgb;
	}

	/* // Visualize number of lights for the first 7 as RGBCMYW
	if ( nNumLightsUsed == 0 )
		o.vDiffuse.rgb = float3( 0.0, 0.0, 0.0 );
	else if ( nNumLightsUsed == 1 )
		o.vDiffuse.rgb = float3( 1.0, 0.0, 0.0 );
	else if ( nNumLightsUsed == 2 )
		o.vDiffuse.rgb = float3( 0.0, 1.0, 0.0 );
	else if ( nNumLightsUsed == 3 )
		o.vDiffuse.rgb = float3( 0.0, 0.0, 1.0 );
	else if ( nNumLightsUsed == 4 )
		o.vDiffuse.rgb = float3( 0.0, 1.0, 1.0 );
	else if ( nNumLightsUsed == 5 )
		o.vDiffuse.rgb = float3( 1.0, 0.0, 1.0 );
	else if ( nNumLightsUsed == 6 )
		o.vDiffuse.rgb = float3( 1.0, 1.0, 0.0 );
	else
		o.vDiffuse.rgb = float3( 1.0, 1.0, 1.0 );
	o.vDiffuse.rgb *= float3( 2.0, 2.0, 2.0 );
	o.vSpecular.rgb = float3( 0.0, 0.0, 0.0 );
	return o;
	//*/

	// Apply specular reflectance to diffuse term (specular term already accounts for this in the fresnel equation)
	o.vDiffuse.rgb *= ( float3( 1.0, 1.0, 1.0 ) - vReflectance.rgb );

	//------------------//
	// Indirect diffuse //
	//------------------//
	#if ( S_OVERRIDE_LIGHTMAP )
	{
		o.vIndirectDiffuse.rgb += ComputeOverrideLightmap( vLightmapUV.xy );
	}
	#elif ( LIGHTMAP_ON )
	{
		// Baked lightmaps
		float4 bakedColorTex = Tex2DLevel( unity_Lightmap, vLightmapUV.xy, 0.0 );
		float3 bakedColor = DecodeLightmap( bakedColorTex );

		#if ( DIRLIGHTMAP_OFF ) // Directional Mode = Non Directional
		{
			o.vIndirectDiffuse.rgb += bakedColor.rgb;

			//o_gi.indirect.diffuse = bakedColor;
			//
			//#ifdef SHADOWS_SCREEN
			//	o_gi.indirect.diffuse = MixLightmapWithRealtimeAttenuation (o_gi.indirect.diffuse, data.atten, bakedColorTex);
			//#endif // SHADOWS_SCREEN
		}
		#elif ( DIRLIGHTMAP_COMBINED ) // Directional Mode = Directional
		{
			//o.vIndirectDiffuse.rgb = float3( 0.0, 1.0, 0.0 );

			float4 bakedDirTex = Tex2DLevelFromSampler( unity_LightmapInd, unity_Lightmap, vLightmapUV.xy, 0.0 );
			//float flHalfLambert = dot( vNormalWs.xyz, bakedDirTex.xyz - 0.5 ) + 0.5;
			//o.vIndirectDiffuse.rgb += bakedColor.rgb * flHalfLambert / bakedDirTex.w;

			float flHalfLambert = dot( vNormalWs.xyz, normalize( bakedDirTex.xyz - 0.5 ) );// + ( 1.0 - length( bakedDirTex.xyz - 0.5 ) );
			o.vIndirectDiffuse.rgb += bakedColor.rgb * flHalfLambert / ( bakedDirTex.w );

			//#ifdef SHADOWS_SCREEN
			//	o_gi.indirect.diffuse = MixLightmapWithRealtimeAttenuation (o_gi.indirect.diffuse, data.atten, bakedColorTex);
			//#endif // SHADOWS_SCREEN
		}
		#elif ( DIRLIGHTMAP_SEPARATE ) // Directional Mode = Directional Specular
		{
			// Left halves of both intensity and direction lightmaps store direct light; right halves store indirect.
			float2 vUvDirect = vLightmapUV.xy;
			float2 vUvIndirect = vLightmapUV.xy + float2( 0.5, 0.0 );

			// Direct Diffuse
			float4 bakedDirTex = float4( 0.0, 0.0, 0.0, 0.0 );
			if ( !g_bIndirectLightmaps )
			{
				bakedDirTex = Tex2DLevelFromSampler( unity_LightmapInd, unity_Lightmap, vUvDirect.xy, 0.0 );
				
				float flHalfLambert = ClampToPositive( dot( vNormalWs.xyz, normalize( bakedDirTex.xyz - 0.5 ) ) );// + ( 1.0 - length( bakedDirTex.xyz - 0.5 ) );
				o.vDiffuse.rgb += bakedColor.rgb * flHalfLambert / ( bakedDirTex.w );
			}

			// Indirect Diffuse
			float4 bakedIndirTex = float4( 0.0, 0.0, 0.0, 0.0 );
			float3 vBakedIndirectColor = float3( 0.0, 0.0, 0.0 );
			if ( 1 )
			{
				vBakedIndirectColor.rgb = DecodeLightmap( Tex2DLevel( unity_Lightmap, vUvIndirect.xy, 0.0 ) );
				bakedIndirTex = Tex2DLevelFromSampler( unity_LightmapInd, unity_Lightmap, vUvIndirect.xy, 0.0 );

				float flHalfLambert = dot( vNormalWs.xyz, normalize( bakedIndirTex.xyz - 0.5 ) );// + ( 1.0 - length( bakedIndirTex.xyz - 0.5 ) );
				o.vIndirectDiffuse.rgb += vBakedIndirectColor.rgb * flHalfLambert / bakedIndirTex.w;
			}

			// Direct Specular
			if ( !g_bIndirectLightmaps )
			{
				UnityLight o_light;
				o.vIndirectDiffuse.rgb += DecodeDirectionalSpecularLightmap( bakedColor, bakedDirTex, vNormalWs, false, 0, o_light );

				float4 vLightingTerms = ComputeDiffuseAndSpecularTerms( false, true,
																		vNormalWs.xyz, vEllipseUWs.xyz, vEllipseVWs.xyz,
																		o_light.dir.xyz, vPositionToCameraDirWs.xyz,
																		vDiffuseExponent.xy, vSpecularExponent.xy, vSpecularScale.xy, vReflectance.rgb, flFresnelExponent );

				float3 vLightColor = o_light.color;
				float3 vLightMask = vLightColor.rgb;
				o.vSpecular.rgb += vLightingTerms.yzw * vLightMask.rgb;
			}
		}
		#endif
	}
	#elif ( UNITY_SHOULD_SAMPLE_SH )
	{
		// Light probe
		o.vIndirectDiffuse.rgb += ShadeSH9( float4( vNormalWs.xyz, 1.0 ) );
	}
	#endif

	#if ( DYNAMICLIGHTMAP_ON )
	{
		float4 realtimeColorTex = Tex2DLevel( unity_DynamicLightmap, vLightmapUV.zw, 0.0 );
		float3 realtimeColor = DecodeRealtimeLightmap( realtimeColorTex );

		#if ( DIRLIGHTMAP_OFF )
		{
			o.vIndirectDiffuse.rgb += realtimeColor.rgb;
		}
		#elif ( DIRLIGHTMAP_COMBINED )
		{
			float4 realtimeDirTex = Tex2DLevelFromSampler( unity_DynamicDirectionality, unity_DynamicLightmap, vLightmapUV.zw, 0.0 );
			o.vIndirectDiffuse.rgb += DecodeDirectionalLightmap( realtimeColor, realtimeDirTex, vNormalWs );
		}
		#elif ( DIRLIGHTMAP_SEPARATE )
		{
			float4 realtimeDirTex = Tex2DLevelFromSampler( unity_DynamicDirectionality, unity_DynamicLightmap, vLightmapUV.zw, 0.0 );
			o.vIndirectDiffuse.rgb += DecodeDirectionalLightmap( realtimeColor, realtimeDirTex, vNormalWs );

			UnityLight o_light;
			float4 realtimeNormalTex = Tex2DLevelFromSampler( unity_DynamicNormal, unity_DynamicLightmap, vLightmapUV.zw, 0.0 );
			o.vIndirectSpecular.rgb += DecodeDirectionalSpecularLightmap( realtimeColor, realtimeDirTex, vNormalWs, true, realtimeNormalTex, o_light );

			float4 vLightingTerms = ComputeDiffuseAndSpecularTerms( false, true,
																	vNormalWs.xyz, vEllipseUWs.xyz, vEllipseVWs.xyz,
																	o_light.dir.xyz, vPositionToCameraDirWs.xyz,
																	vDiffuseExponent.xy, vSpecularExponent.xy, vSpecularScale.xy, vReflectance.rgb, flFresnelExponent );

			float3 vLightColor = o_light.color;
			float3 vLightMask = vLightColor.rgb;
			o.vSpecular.rgb += vLightingTerms.yzw * vLightMask.rgb;
		}
		#endif
	}
	#endif

	//-------------------//
	// Indirect specular //
	//-------------------//
	#if ( 1 )
	{
		float flRoughness = dot( vRoughness.xy, float2( 0.5, 0.5 ) );

		float3 vReflectionDirWs = CalculateCameraReflectionDirWs( vPositionWs.xyz, vNormalWs.xyz );
		float3 vReflectionDirWs0 = vReflectionDirWs.xyz;
		#if ( UNITY_SPECCUBE_BOX_PROJECTION )
		{
			vReflectionDirWs0.xyz = BoxProjectedCubemapDirection( vReflectionDirWs.xyz, vPositionWs.xyz, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax );
		}
		#endif

		float3 vEnvMap0 = max( 0.0, Unity_GlossyEnvironment( UNITY_PASS_TEXCUBE( unity_SpecCube0 ), unity_SpecCube0_HDR, vReflectionDirWs0, flRoughness ) );
		#if ( UNITY_SPECCUBE_BLENDING )
		{
			const float flBlendFactor = 0.99999;
			float flBlendLerp = saturate( unity_SpecCube0_BoxMin.w );
			UNITY_BRANCH
			if ( flBlendLerp < flBlendFactor )
			{
				float3 vReflectionDirWs1 = vReflectionDirWs.xyz;
				#if ( UNITY_SPECCUBE_BOX_PROJECTION )
				{
					vReflectionDirWs1.xyz = BoxProjectedCubemapDirection( vReflectionDirWs.xyz, vPositionWs.xyz, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax );
				}
				#endif

				float3 vEnvMap1 = max( 0.0, Unity_GlossyEnvironment( UNITY_PASS_TEXCUBE_SAMPLER( unity_SpecCube1, unity_SpecCube0 ), unity_SpecCube1_HDR, vReflectionDirWs1, flRoughness ) );
				o.vIndirectSpecular.rgb += lerp( vEnvMap1.rgb, vEnvMap0.rgb, flBlendLerp );
			}
			else
			{
				o.vIndirectSpecular.rgb += vEnvMap0.rgb;
			}
		}
		#else
		{
			o.vIndirectSpecular.rgb += vEnvMap0.rgb;
		}
		#endif
	}
	#endif

	// Apply fresnel to indirect specular
	float flVDotN = saturate( dot( vPositionToCameraDirWs.xyz, vNormalWs.xyz ) );
	float3 vMaxReflectance = ( ( vReflectance.rgb + 0.001 ) / Luminance( vReflectance.rgb + 0.001 ) ) * g_flReflectanceMax;
	float3 vFresnel = lerp( vReflectance.rgb, vMaxReflectance.rgb, pow( 1.0 - flVDotN, flFresnelExponent ) );

	o.vIndirectSpecular.rgb *= vFresnel.rgb;
	o.vIndirectSpecular.rgb *= g_flCubeMapScalar; // !!! FIXME: This also contains lightmap spec

	// Since we have indirect specular, apply reflectance to indirect diffuse
	o.vIndirectDiffuse.rgb *= ( float3( 1.0, 1.0, 1.0 ) - vReflectance.rgb );

	return o;
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------
LightingTerms_t ComputeLightingDiffuseOnly( float3 vPositionWs, float3 vNormalWs, float3 vTangentUWs, float3 vTangentVWs, float2 vRoughness, float4 vLightmapUV )
{
	LightingTerms_t lightingTerms = ComputeLighting( vPositionWs, vNormalWs, vTangentUWs, vTangentVWs, vRoughness, 0.0, 1.0, vLightmapUV.xyzw );

	lightingTerms.vSpecular = float3( 0.0, 0.0, 0.0 );
	lightingTerms.vIndirectSpecular = float3( 0.0, 0.0, 0.0 );

	return lightingTerms;
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------
float3 CubeMapBoxProjection( float3 vPositionCubemapLocal, float3 vNormalCubemapLocal, float3 vCameraPositionCubemapLocal, float3 vBoxMins, float3 vBoxMaxs )
{
	float3 vCameraToPositionRayCubemapLocal = vPositionCubemapLocal.xyz - vCameraPositionCubemapLocal.xyz;
	float3 vCameraToPositionRayReflectedCubemapLocal = reflect( vCameraToPositionRayCubemapLocal.xyz, vNormalCubemapLocal.xyz );

	float3 vIntersectA = ( vBoxMaxs.xyz - vPositionCubemapLocal.xyz ) / vCameraToPositionRayReflectedCubemapLocal.xyz;
	float3 vIntersectB = ( vBoxMins.xyz - vPositionCubemapLocal.xyz ) / vCameraToPositionRayReflectedCubemapLocal.xyz;

	float3 vIntersect = max( vIntersectA.xyz, vIntersectB.xyz );
	float flDistance = min( vIntersect.x, min( vIntersect.y, vIntersect.z ) );

	float3 vReflectDirectionWs = vPositionCubemapLocal.xyz + vCameraToPositionRayReflectedCubemapLocal.xyz * flDistance;

	return vReflectDirectionWs;
}

#endif
