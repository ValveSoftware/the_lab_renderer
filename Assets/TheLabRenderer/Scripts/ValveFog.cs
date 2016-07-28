// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================

using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class ValveFog : MonoBehaviour
{
	[Header( "Gradient Fog" )]

	public Gradient gradient = new Gradient();
	public float startDistance = 0.0f;
	public float endDistance = 100.0f;
	public int textureWidth = 32;

	[Header( "Height Fog")]

	public Color heightFogColor = Color.grey;
	public float heightFogThickness = 1.15f;
	public float heightFogFalloff = 0.1f;
	public float heightFogBaseHeight = -40.0f;

	// Textures
	private Texture2D gradientFogTexture;

	void Start()
	{
		UpdateConstants();
	}

	void OnEnable()
	{
		Shader.EnableKeyword( "D_VALVE_FOG" );
	}

	void OnDisable()
	{
		Shader.DisableKeyword( "D_VALVE_FOG" );
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
		if ( gradientFogTexture == null )
		{
			GenerateTexture();
		}

		float scale = 1.0f / ( endDistance - startDistance );
		float add = -startDistance / ( endDistance - startDistance );
		Shader.SetGlobalVector( "gradientFogScaleAdd", new Vector4( scale, add, 0.0f, 0.0f ) );
		Shader.SetGlobalColor( "gradientFogLimitColor", gradient.Evaluate( 1.0f ).linear );
		Shader.SetGlobalVector( "heightFogParams", new Vector4( heightFogThickness, heightFogFalloff, heightFogBaseHeight, 0.0f ) );
		Shader.SetGlobalColor( "heightFogColor", heightFogColor.linear );
	}

	public void GenerateTexture()
	{
		gradientFogTexture = new Texture2D( textureWidth, 1, TextureFormat.ARGB32, false );

		gradientFogTexture.wrapMode = TextureWrapMode.Clamp;

		float ds = 1.0f / ( textureWidth - 1 );
		float s = 0.0f;
		for ( int i = 0; i < textureWidth; i++ )
		{
			gradientFogTexture.SetPixel( i, 0, gradient.Evaluate( s ) );
			s += ds;
		}
		gradientFogTexture.Apply();

		Shader.SetGlobalTexture( "gradientFogTexture", gradientFogTexture );
	}
}

#if UNITY_EDITOR
[UnityEditor.CustomEditor( typeof( ValveFog ) )]
public class ValveGradientFogEditor : UnityEditor.Editor
{
	// Custom Inspector GUI allows us to click from within the UI
	public override void OnInspectorGUI()
	{
		DrawDefaultInspector();

		ValveFog gradientFog = ( ValveFog )target;

		gradientFog.GenerateTexture();
	}
}
#endif
