// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================

using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class ValveOverrideLightmap : MonoBehaviour
{
	public Color m_colorTint = Color.white;
	[Range( 0.0f, 16.0f )] public float m_brightness = 1.0f;

	void Start()
	{
		UpdateConstants();
	}

	#if UNITY_EDITOR
		void Update()
		{
			if ( !Application.isPlaying )
			{
				UpdateConstants();
			}
		}
	#endif

	private void UpdateConstants()
	{
		Shader.SetGlobalColor( "g_vOverrideLightmapScale", m_brightness * m_colorTint.linear );
	}
}
