// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================

using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;

[ExecuteInEditMode]
[RequireComponent( typeof( Light ) )]
public class ValveRealtimeLight : MonoBehaviour
{
	[NonSerialized] [HideInInspector] public static List< ValveRealtimeLight > s_allLights = new List< ValveRealtimeLight >();
	[NonSerialized] [HideInInspector] public Light m_cachedLight;
	[NonSerialized] [HideInInspector] public Matrix4x4[] m_shadowTransform = { Matrix4x4.identity, Matrix4x4.identity, Matrix4x4.identity, Matrix4x4.identity, Matrix4x4.identity, Matrix4x4.identity };
	[NonSerialized] [HideInInspector] public Matrix4x4[] m_lightCookieTransform = { Matrix4x4.identity, Matrix4x4.identity, Matrix4x4.identity, Matrix4x4.identity, Matrix4x4.identity, Matrix4x4.identity };
	[NonSerialized] [HideInInspector] public int[] m_shadowX = { 0, 0, 0, 0, 0, 0 };
	[NonSerialized] [HideInInspector] public int[] m_shadowY = { 0, 0, 0, 0, 0, 0 };
	[NonSerialized] [HideInInspector] public bool m_bRenderShadowsThisFrame = false;
	[NonSerialized] [HideInInspector] public bool m_bInCameraFrustum = false;

	//[Tooltip( "Health value between 0 and 100." )]

	//[Header( "Spotlight Settings" )]
	[Range( 0.0f, 100.0f )] public float m_innerSpotPercent = 50.0f;

	//[Header( "Shadow Settings" )]
	[Range( 128.0f, 1024.0f * 8.0f )] public int m_shadowResolution = 1024;
	public float m_shadowNearClipPlane = 1.0f;
	public LayerMask m_shadowCastLayerMask = ~0;

	// !!! I need to hide these values for non-directional lights
	public float m_directionalLightShadowRadius = 100.0f;
	public float m_directionalLightShadowRange = 100.0f;

	public bool m_useOcclusionCullingForShadows = true;

	void OnValidate()
	{
		//if ( !Mathf.IsPowerOfTwo( m_shadowResolution ) )
		//{
		//	m_shadowResolution = Mathf.ClosestPowerOfTwo( m_shadowResolution );
		//}

		if ( ( m_shadowResolution % 128 ) != 0 )
		{
			m_shadowResolution -= m_shadowResolution % 128;
		}

		if ( m_shadowNearClipPlane < 0.01f )
		{
			m_shadowNearClipPlane = 0.01f;
		}
	}

	void OnEnable()
	{
		if ( !s_allLights.Contains( this ) )
		{
			s_allLights.Add( this );
			m_cachedLight = GetComponent< Light >();
		}
	}

	void OnDisable()
	{
		s_allLights.Remove( this );
	}

	public bool IsEnabled()
	{
		Light l = m_cachedLight;

		if ( !l.enabled || !l.isActiveAndEnabled )
		{
			//Debug.Log( "Skipping disabled light " + l.name );
			return false;
		}

		if ( l.intensity <= 0.0f )
		{
			//Debug.Log( "Skipping light with zero intensity " + l.name );
			return false;
		}

		if ( l.range <= 0.0f )
		{
			//Debug.Log( "Skipping light with zero range " + l.name );
			return false;
		}

		if ( ( l.color.linear.r <= 0.0f ) && ( l.color.linear.g <= 0.0f ) && ( l.color.linear.b <= 0.0f ) )
		{
			//Debug.Log( "Skipping black light " + l.name );
			return false;
		}

		if ( l.isBaked )
		{
			// AV - Disabling this early-out because we may want lights to bake indirect and have realtime direct
			//Debug.Log( "Skipping lightmapped light " + l.name );
			//return false;
		}

		if ( !m_bInCameraFrustum  )
		{
			//Debug.Log( "Skipping light culled by camera frustum " + l.name );
			return false;
		}

		return true;
	}

	public bool CastsShadows()
	{
		Light l = m_cachedLight;

		if ( ( ( l.type == LightType.Spot ) || ( l.type == LightType.Point ) || ( l.type == LightType.Directional ) ) && ( l.shadows != LightShadows.None ) )
		{
			return true;
		}

		return false;
	}
}
