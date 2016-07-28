// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================

#ifndef VR_FOG_INCLUDED
#define VR_FOG_INCLUDED

uniform half2 gradientFogScaleAdd;
uniform half3 gradientFogLimitColor;
uniform half3 heightFogParams;
uniform half3 heightFogColor;

uniform sampler2D gradientFogTexture;

//---------------------------------------------------------------------------------------------------------------------------------------------------------
half2 CalculateFogCoords( float3 posWs )
{
	half2 results = 0.0;

	// Gradient fog
	half d = distance( posWs, _WorldSpaceCameraPos );
	results.x = saturate( gradientFogScaleAdd.x * d + gradientFogScaleAdd.y );

	// Height fog
	half3 cameraToPositionRayWs = posWs.xyz - _WorldSpaceCameraPos.xyz;
	half cameraToPositionDist = length( cameraToPositionRayWs.xyz );
	half3 cameraToPositionDirWs = normalize( cameraToPositionRayWs.xyz );
	half h = _WorldSpaceCameraPos.y - heightFogParams.z;
	results.y = heightFogParams.x * exp( -h * heightFogParams.y ) *
		( 1.0 - exp( -cameraToPositionDist * cameraToPositionDirWs.y * heightFogParams.y ) ) / cameraToPositionDirWs.y;
	
	return saturate( results.xy );
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------
half3 ApplyFog( half3 c, half2 fogCoord, float fogMultiplier )
{
	// Apply gradient fog
	half4 f = tex2D( gradientFogTexture, half2( fogCoord.x, 0.0f ) ).rgba;
	c.rgb = lerp( c.rgb, f.rgb * fogMultiplier, f.a );

	// Apply height fog
	c.rgb = lerp( c.rgb, heightFogColor.rgb * fogMultiplier, fogCoord.y );

	return c.rgb;
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------
half3 ApplyFog( half3 c, half2 fogCoord )
{
	return ApplyFog( c.rgb, fogCoord.xy, 1.0 );
}

#endif // VR_FOG_INCLUDED
