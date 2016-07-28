// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================

#ifndef VALVE_VR_MATRIX_PALETTE_SKINNING_INCLUDED
#define VALVE_VR_MATRIX_PALETTE_SKINNING_INCLUDED

#if defined( MATRIX_PALETTE_SKINNING_1BONE ) || defined( MATRIX_PALETTE_SKINNING_2BONE ) || defined( MATRIX_PALETTE_SKINNING_3BONE ) || defined( MATRIX_PALETTE_SKINNING_4BONE )
	#define MATRIX_PALETTE_SKINNING 1
#endif

uniform StructuredBuffer< float4x4 > matrixPalette;

//---------------------------------------------------------------------------------------------------------------------------------------------------------
void MatrixPaletteSkinning( inout float4 io_vPositionOs, inout float3 io_vNormalOs, inout float3 io_vTangentUOs, float4 vBoneIndices )
{
	vBoneIndices.xyzw = vBoneIndices.xyzw * 255.0;

	io_vPositionOs.xyzw = mul( matrixPalette[ vBoneIndices[ 0 ] ], io_vPositionOs.xyzw );
	io_vNormalOs.xyz = mul( matrixPalette[ vBoneIndices[ 0 ] ], float4( io_vNormalOs.xyz, 0.0 ) );
	io_vTangentUOs.xyz = mul( matrixPalette[ vBoneIndices[ 0 ] ], float4( io_vTangentUOs.xyz, 0.0 ) );
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------
void MatrixPaletteSkinning( inout float4 io_vPositionOs, inout float3 io_vNormalOs, float4 vBoneIndices )
{
	float3 garbage = 0.0;
	MatrixPaletteSkinning( io_vPositionOs.xyzw, io_vNormalOs.xyz, garbage.xyz, vBoneIndices );
}

//---------------------------------------------------------------------------------------------------------------------------------------------------------
void MatrixPaletteSkinning( inout float4 io_vPositionOs, float4 vBoneIndices )
{
	float3 garbage1 = 0.0;
	float3 garbage2 = 0.0;
	MatrixPaletteSkinning( io_vPositionOs.xyzw, garbage1.xyz, garbage2.xyz, vBoneIndices );
}
			
#endif // VALVE_VR_MATRIX_PALETTE_SKINNING_INCLUDED
