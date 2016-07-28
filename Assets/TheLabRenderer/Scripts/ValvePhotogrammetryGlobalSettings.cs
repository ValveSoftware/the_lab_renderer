// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================

using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class ValvePhotogrammetryGlobalSettings : MonoBehaviour
{
	public Color shadowColor;

	private int shadowColorID;

	//-----------------------------------------------------
	void Awake()
	{
		shadowColorID = Shader.PropertyToID( "g_vPhotogrammetryShadowColor" );
	}

	//-----------------------------------------------------
	void Update()
	{
		Shader.SetGlobalVector( shadowColorID, shadowColor.linear );
	}
}
