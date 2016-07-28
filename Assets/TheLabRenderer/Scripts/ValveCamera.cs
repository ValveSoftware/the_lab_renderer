// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================
//
// Scene setup:
//    - Enable forward renderer in Player Project Settings
//    - Set Color Space to Linear in Player Project Settings
//    - Enable GPU Skinning in Player Project Settings
//	  - Add the ValveCamera.cs script to the main camera
//	  - Add the ValveRealtimeLight.cs script to all runtime lights
//    - In Project Quality Settings, set Shadow Cascades to No Cascades
//    - In Project Quality Settings, set Pixel Light Count = 99
//
//-------------------------------------------------------------------------------------------------------------------------------------------------------------

using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine.VR;
#if ( UNITY_EDITOR )
	using UnityEditor;
#endif

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
[ExecuteInEditMode]
[RequireComponent( typeof( Camera ) )]
public class ValveCamera : MonoBehaviour
{
	[NonSerialized] const float DIRECTIONAL_LIGHT_PULLBACK_DISTANCE = 10000.0f; // Directional lights become spotlights at a far distance. This is the distance we pull back to set the spotlight origin.

	[NonSerialized] const int MAX_LIGHTS = 18;
	[Header( "Lights & Shadows" )]
	[Range( 1024.0f, 1024.0f * 8.0f )] public int m_valveShadowTextureWidth = 1024 * 4;
	[Range( 1024.0f, 1024.0f * 8.0f )] public int m_valveShadowTextureHeight = 1024 * 4;

	//[Tooltip( "Might cause shadow acne on skinned meshes, but can be more efficient in scenes without skinned meshes" )]
	//public bool m_renderShadowsInLateUpdate = false;

	[NonSerialized] private Camera m_shadowCamera = null;
	[NonSerialized] public RenderTexture m_shadowDepthTexture = null;
	[NonSerialized] public Shader m_shaderCastShadows = null;

	#if ( UNITY_EDITOR )
		[NonSerialized] private Camera m_editorCamera = null;
		[NonSerialized] public Shader m_shaderShadowVis = null;
		[NonSerialized] public Material m_materialShadowVis = null;
	#endif

	[Tooltip( "Requires 'Directional Specular' General GI Mode" )]
	public bool m_indirectLightmapsOnly = false;

	[Header( "Adaptive Quality" )]
	[Tooltip( "Automatically adjusts render quality to maintain VR framerate" )]
	public bool m_adaptiveQualityEnabled = true;
	[Tooltip( "Shows Debug Overlay [Shift+F1] or launch with -vrdebug" )]
	public bool m_adaptiveQualityDebugVis = false;

	[Range( 0.0f, 8.0f )] public int m_MSAALevel = 4;
	public float m_minRenderTargetScale = 0.8f;
	public float m_maxRenderTargetScale = 1.4f;
	[NonSerialized] private int m_nFillRatePercentStep = 15;
	public int m_maxRenderTargetDimension = 4096;

	[NonSerialized] private static bool s_bUsingStaticSettings = false;
	[NonSerialized] private static bool s_bAdaptiveQualityVRDebug = false;
	[NonSerialized] private static bool s_bAdaptiveQualityVROverride = false;
	[NonSerialized] private static int s_nAdaptiveQualityVROverride = 0;
	[NonSerialized] private static bool m_bAllowFlush = true;

	[NonSerialized] private GameObject m_adaptiveQualityDebugQuad;

	[Header( "Helper" )]
	public bool m_cullLightsInSceneEditor = false;
	public bool m_cullLightsFromEditorCamera = false;
	public bool m_hideAllValveMaterials = false;

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	public static bool HasCommandLineArg( string argumentName )
	{
		string[] args = System.Environment.GetCommandLineArgs();
		for ( int i = 0; i < args.Length; i++ )
		{
			if ( args[ i ].Equals( argumentName ) )
			{
				return true;
			}
		}

		return false;
	}

	public static int GetCommandLineArgValue( string argumentName, int nDefaultValue )
	{
		string[] args = System.Environment.GetCommandLineArgs();
		for ( int i = 0; i < args.Length; i++ )
		{
			if ( args[ i ].Equals( argumentName ) )
			{
				if ( i == ( args.Length - 1 ) ) // Last arg, return default
				{
					return nDefaultValue;
				}

				return Int32.Parse( args[ i + 1 ] );
			}
		}

		return nDefaultValue;
	}

	public static float GetCommandLineArgValue( string argumentName, float flDefaultValue )
	{
		string[] args = System.Environment.GetCommandLineArgs();
		for ( int i = 0; i < args.Length; i++ )
		{
			if ( args[ i ].Equals( argumentName ) )
			{
				if ( i == ( args.Length - 1 ) ) // Last arg, return default
				{
					return flDefaultValue;
				}

				return ( float )Double.Parse( args[ i + 1 ] );
			}
		}

		return flDefaultValue;
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	int ClampMSAA( int nMSAA )
	{
		if ( nMSAA < 2 )
			return 0;
		else if ( nMSAA < 4 )
			return 2;
		else if ( nMSAA < 8 )
			return 4;
		else
			return 8;
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	void OnValidate()
	{
		if ( ( m_valveShadowTextureWidth % 128 ) != 0 )
		{
			m_valveShadowTextureWidth -= m_valveShadowTextureWidth % 128;
		}

		if ( ( m_valveShadowTextureHeight % 128 ) != 0 )
		{
			m_valveShadowTextureHeight -= m_valveShadowTextureHeight % 128;
		}

		m_MSAALevel = ClampMSAA( m_MSAALevel );
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	void OnEnable()
	{
		if ( HasCommandLineArg( "-noflush" ) )
		{
			m_bAllowFlush = false;
		}

		if ( HasCommandLineArg( "-noaq" ) )
		{
			m_adaptiveQualityEnabled = false;
		}

		if ( HasCommandLineArg( "-aqoverride" ) )
		{
			s_bAdaptiveQualityVROverride = true;
			s_nAdaptiveQualityVROverride = GetCommandLineArgValue( "-aqoverride", 0 );
		}

		if ( !s_bUsingStaticSettings )
		{
			s_bUsingStaticSettings = true;

			if ( HasCommandLineArg( "-vrdebug" ) )
			{
				s_bAdaptiveQualityVRDebug = true;
			}

			if ( m_adaptiveQualityDebugVis )
			{
				s_bAdaptiveQualityVRDebug = true;
			}
		}

		if ( Application.isPlaying )
		{
			int nMSAALevel = ClampMSAA( GetCommandLineArgValue( "-msaa", m_MSAALevel ) );
			QualitySettings.antiAliasing = nMSAALevel;
			Debug.Log( "[Valve Camera] Setting MSAA to " + nMSAALevel + "x\n" );
		}

		InitializeAdaptiveQualityScale();

		CreateAssets();

		#if ( UNITY_EDITOR )
		{
			if ( !Application.isPlaying )
			{
				// Move our script to the end of the execution order so we are last through LateUpdate() where we want to render shadows after IK
				int executionOrder = 0x7fff;
				MonoScript monoScript = MonoScript.FromMonoBehaviour( this );
				int currentExecutionOrder = MonoImporter.GetExecutionOrder( monoScript );
				if ( currentExecutionOrder != executionOrder )
				{
					MonoImporter.SetExecutionOrder( monoScript, executionOrder );
				}
			}

			if ( !EditorApplication.isPlaying )
			{
				EditorApplication.update += MyEditorUpdate;
			}
		}
		#endif
	}

	void OnDisable()
	{
		#if ( UNITY_EDITOR )
		{
			if ( !EditorApplication.isPlaying )
			{
				EditorApplication.update -= MyEditorUpdate;
			}
		}
		#endif
	}

	void OnDestroy()
	{
		if ( m_shadowDepthTexture )
		{
			DestroyImmediate( m_shadowDepthTexture );
			m_shadowDepthTexture = null;
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	void CreateAssets()
	{
		// Create camera
		if ( !m_shadowCamera )
		{
			m_shadowCamera = CreateRenderCamera( "Valve Shadow Camera" );
			m_cullLightsInSceneEditor = false;
			m_cullLightsFromEditorCamera = false;
			m_hideAllValveMaterials = false;
		}

		// Shadow depth texture
		if ( !m_shadowDepthTexture || ( m_shadowDepthTexture.width != m_valveShadowTextureWidth ) || ( m_shadowDepthTexture.height != m_valveShadowTextureHeight ) )
		{
			if ( m_shadowDepthTexture )
			{
				DestroyImmediate( m_shadowDepthTexture );
				m_shadowDepthTexture = null;
			}

			m_shadowDepthTexture = new RenderTexture( m_valveShadowTextureWidth, m_valveShadowTextureHeight, 24, RenderTextureFormat.Shadowmap, RenderTextureReadWrite.Linear );
			if ( m_shadowDepthTexture )
			{
				m_shadowDepthTexture.name = "m_shadowDepthTexture";
				m_shadowDepthTexture.hideFlags = HideFlags.HideAndDontSave;
				m_shadowDepthTexture.useMipMap = false;
				m_shadowDepthTexture.filterMode = FilterMode.Bilinear;
				m_shadowDepthTexture.wrapMode = TextureWrapMode.Clamp;
				m_shadowDepthTexture.antiAliasing = 1;
				m_shadowDepthTexture.Create();
				m_shadowDepthTexture.SetGlobalShaderProperty( "g_tShadowBuffer" );
				//Shader.SetGlobalTexture( "g_tShadowBuffer", m_shadowDepthTexture );
				#if ( UNITY_EDITOR )
				{
					EditorUtility.SetDirty( this );
				}
				#endif
			}
			else
			{
				Debug.LogWarning( "ERROR! Cannot create shadow depth texture!\n" );
			}
		}

		// Cast shadows shader
		if ( !m_shaderCastShadows )
		{
			m_shaderCastShadows = Resources.Load( "vr_cast_shadows" ) as Shader;
			if ( !m_shaderCastShadows )
			{
				Debug.LogWarning( "ERROR! Can't find Resources/vr_cast_shadows!\n" );
			}
			else if ( !m_shaderCastShadows.isSupported )
			{
				Debug.LogWarning( "ERROR! Resources/vr_cast_shadows not supported!\n" );
			}
		}

		// Shadows vis shader and material
		#if ( UNITY_EDITOR )
		{
			if ( !m_shaderShadowVis )
			{
				m_shaderShadowVis = Resources.Load( "vr_shadow_vis" ) as Shader;
				if ( !m_shaderShadowVis )
				{
					Debug.LogWarning( "ERROR! Can't find Resources/vr_shadow_vis!\n" );
				}
				else if ( !m_shaderShadowVis.isSupported )
				{
					Debug.LogWarning( "ERROR! Resources/vr_shadow_vis not supported!\n" );
				}
				else
				{
					m_materialShadowVis = new Material( m_shaderShadowVis );
					m_materialShadowVis.hideFlags = HideFlags.HideAndDontSave;
				}
			}
		}
		#endif
	}

	// Creates an inactive camera for rendering support data
	private static Camera CreateRenderCamera( string name )
	{
		var go = GameObject.Find( name );
		if ( !go )
		{
			go = new GameObject( name );
		}

		Camera goCamera = go.GetComponent< Camera >();
		if ( !goCamera )
		{
			goCamera = go.AddComponent< Camera >();
		}

		go.hideFlags = HideFlags.HideAndDontSave;
		goCamera.enabled = false;
		goCamera.renderingPath = RenderingPath.Forward;
		goCamera.nearClipPlane = 0.1f;
		goCamera.farClipPlane = 100.0f;
		goCamera.depthTextureMode = DepthTextureMode.None;
		goCamera.clearFlags = CameraClearFlags.Depth;
		goCamera.backgroundColor = Color.white;
		goCamera.orthographic = false;
		goCamera.hideFlags = HideFlags.HideAndDontSave;
		go.SetActive( false );
		return goCamera;
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	[NonSerialized] private int g_nNumFlushesThisFrame = 0;
	[NonSerialized] private int m_nFlushCounterFrameCount = 0;
	void ValveGLFlush()
	{
		// Don't flush if run with -noflush
		if ( !m_bAllowFlush )
		{
			return;
		}

		// Only flush 4 times in a given frame
		if ( m_nFlushCounterFrameCount != Time.frameCount )
		{
			m_nFlushCounterFrameCount = Time.frameCount;
			g_nNumFlushesThisFrame = 0;
		}

		if ( ++g_nNumFlushesThisFrame > 3 )
		{
			return;
		}

		// Flush
		GL.Flush();
	}

	void ValveGLFlushIfNotReprojecting()
	{
		// Don't flush while reprojecting
		if ( Valve.VRRenderingPackage.OpenVR.Compositor != null )
		{
			var timing = new Valve.VRRenderingPackage.Compositor_FrameTiming();
			timing.m_nSize = ( uint )System.Runtime.InteropServices.Marshal.SizeOf( typeof( Valve.VRRenderingPackage.Compositor_FrameTiming ) );
			Valve.VRRenderingPackage.OpenVR.Compositor.GetFrameTiming( ref timing, 0 );
		
			if ( timing.m_nNumFramePresents > 1 )
				return;
		}

		ValveGLFlush();
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	// Helper functions paired with ValveSceneAutoRendering at the bottom of this file to keep the editor rendering unthrottled
	//---------------------------------------------------------------------------------------------------------------------------------------------------
	void MyEditorUpdate()
	{
		#if ( UNITY_EDITOR )
		{
			if ( !EditorApplication.isPlaying )
			{
				// Update pointer to scene editor camera for shadow culling
				if ( Camera.current && Camera.current.name.Equals( "SceneCamera" ) )
				{
					m_editorCamera = Camera.current;
				}

				//Debug.Log( "MyEditorUpdate() " + this.name + "\n\n" );
				CreateAssets();
				ValveShadowBufferRender();

				// Add the ValveCamera.cs script to the scene camera
				//if ( Camera.current && Camera.current.name.Equals( "SceneCamera" ) )
				//{
				//	if ( !Camera.current.gameObject.GetComponent( "ValveCamera") )
				//	{
				//		//Debug.Log( "Adding ValveCamera.cs script to " + Camera.current.name + "\n\n" );
				//		Camera.current.gameObject.AddComponent<ValveCamera>();
				//	}
				//}

				// Force scene to render
				if ( ValveSceneAutoRendering.s_bSceneAutoRender )
				{
					EditorUtility.SetDirty( this );
				}
			}
		}
		#endif
	}

	// NOTE: We want to call ValveShadowBufferRender() in LateUpdate() since that is before WaitGetPoses() gets called internally
	//       by Unity. This allows all shadow rendering to be queued on the render thread waiting to be executed immediately at
	//       running start when WaitGetPoses() returns. This helps ensure there are no GPU bubbles at the top of the frame.
	void LateUpdate()
	{
		//Debug.Log( "LateUpdate() " + this.name + "\n\n" );
		//MyEditorUpdate();
		//if ( m_renderShadowsInLateUpdate )
		//{
		//	ValveShadowBufferRender();
		//}

		// Adaptive quality debug quad
		if ( Application.isPlaying )
		{
			// Toggle debug quad on shift-F1
			if ( Input.GetKeyDown( KeyCode.F1 ) && ( Input.GetKey( KeyCode.LeftShift ) || Input.GetKey( KeyCode.RightShift ) ) )
			{
				s_bAdaptiveQualityVRDebug = s_bAdaptiveQualityVRDebug ? false : true;
			}

			if ( Input.GetKeyDown( KeyCode.F2 ) && ( Input.GetKey( KeyCode.LeftShift ) || Input.GetKey( KeyCode.RightShift ) ) )
			{
				s_bAdaptiveQualityVROverride = s_bAdaptiveQualityVROverride ? false : true;
				s_nAdaptiveQualityVROverride = m_nAdaptiveQualityLevel;
			}

			if ( Input.GetKeyDown( KeyCode.F3 ) && ( Input.GetKey( KeyCode.LeftShift ) || Input.GetKey( KeyCode.RightShift ) ) )
			{
				s_nAdaptiveQualityVROverride = Mathf.Max( s_nAdaptiveQualityVROverride - 1, 0 );
			}

			if ( Input.GetKeyDown( KeyCode.F4 ) && ( Input.GetKey( KeyCode.LeftShift ) || Input.GetKey( KeyCode.RightShift ) ) )
			{
				s_nAdaptiveQualityVROverride++;
			}

			if ( m_adaptiveQualityEnabled && s_bAdaptiveQualityVRDebug && !m_adaptiveQualityDebugQuad )
			{
				Mesh mesh = new Mesh();
				mesh.vertices = new Vector3[]
				{
					new Vector3( -0.5f, 0.9f, 1.0f ),
					new Vector3( -0.5f, 1.0f, 1.0f ),
					new Vector3(  0.5f, 1.0f, 1.0f ),
					new Vector3(  0.5f, 0.9f, 1.0f )
				};
				mesh.uv = new Vector2[]
				{
					new Vector2( 0.0f, 0.0f ),
					new Vector2( 0.0f, 1.0f ),
					new Vector2( 1.0f, 1.0f ),
					new Vector2( 1.0f, 0.0f )
				};
				mesh.triangles = new int[]
				{
					0, 1, 2, 0, 2, 3
				};
				mesh.Optimize();
				mesh.UploadMeshData( false );

				m_adaptiveQualityDebugQuad = new GameObject( "AdaptiveQualityDebugQuad" );
				m_adaptiveQualityDebugQuad.transform.parent = transform;
				m_adaptiveQualityDebugQuad.transform.localPosition = Vector3.forward * 1.0f;
				m_adaptiveQualityDebugQuad.transform.localRotation = Quaternion.Euler( 0.0f, 0.0f, 0.0f );
				m_adaptiveQualityDebugQuad.AddComponent<MeshFilter>().mesh = mesh;
				if ( Resources.Load( "adaptive_quality_debug" ) as Material )
				{
					m_adaptiveQualityDebugQuad.AddComponent<MeshRenderer>().material = Resources.Load( "adaptive_quality_debug" ) as Material;
					( Resources.Load( "adaptive_quality_debug" ) as Material ).renderQueue = 4000;
				}
			}
			else if ( !s_bAdaptiveQualityVRDebug && m_adaptiveQualityDebugQuad )
			{
				// Destroy
				DestroyImmediate( m_adaptiveQualityDebugQuad );
				m_adaptiveQualityDebugQuad = null;
			}
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	void OnPreCull()
	{
		UpdateAdaptiveQuality();
		//if ( !m_renderShadowsInLateUpdate )
		{
			ValveShadowBufferRender();
		}
	}

	void OnPostRender()
	{
		ValveGLFlush();
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	void ValveShadowBufferRender()
	{
		CullLightsAgainstCameraFrustum();
		RenderShadowBuffer();
		UpdateLightConstants();
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	[NonSerialized] private int m_nAdaptiveQualityLevel = 0;

	[NonSerialized] private int m_nAdaptiveQualityFrameCountLastChanged = 0;
	[NonSerialized] private float[] m_adaptiveQualityRingBuffer = { 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f };
	[NonSerialized] private int m_nAdaptiveQualityRingBufferPos = 0;

	[NonSerialized] private bool m_bInterleavedReprojectionEnabled = false;

	[NonSerialized] private List<float> m_adaptiveQualityRenderScaleArray = new List<float>();
	[NonSerialized] private int m_adaptiveQualityNumLevels = 0;
	[NonSerialized] private int m_adaptiveQualityDefaultLevel = 0;

	void InitializeAdaptiveQualityScale()
	{
		// Get command line overrides
		float flMinRenderTargetScale = GetCommandLineArgValue( "-aqminscale", m_minRenderTargetScale );
		float flMaxRenderTargetScale = GetCommandLineArgValue( "-aqmaxscale", m_maxRenderTargetScale );
		int nFillRatePercentStep = GetCommandLineArgValue( "-aqfillratestep", m_nFillRatePercentStep );

		int nMaxRenderTargetDimension = m_maxRenderTargetDimension;
		if ( HasCommandLineArg( "-aqmaxres" ) )
		{
			nMaxRenderTargetDimension = GetCommandLineArgValue( "-aqmaxres", nMaxRenderTargetDimension );
			flMaxRenderTargetScale = Mathf.Min( ( float )nMaxRenderTargetDimension / ( float )VRSettings.eyeTextureWidth, ( float )nMaxRenderTargetDimension / ( float )VRSettings.eyeTextureHeight );
		}

		// Clear array
		m_adaptiveQualityRenderScaleArray.Clear();

		// Add min as the reprojection bin
		m_adaptiveQualityRenderScaleArray.Add( flMinRenderTargetScale );

		// Add all entries
		float flCurrentScale = flMinRenderTargetScale;
		while ( flCurrentScale <= flMaxRenderTargetScale )
		{
			m_adaptiveQualityRenderScaleArray.Add( flCurrentScale );
			flCurrentScale = Mathf.Sqrt( ( ( float )( nFillRatePercentStep + 100 ) / 100.0f ) * flCurrentScale * flCurrentScale );

			if ( ( ( flCurrentScale * VRSettings.eyeTextureWidth ) > nMaxRenderTargetDimension ) || ( ( flCurrentScale * VRSettings.eyeTextureHeight ) > nMaxRenderTargetDimension ) )
			{
				// Too large
				break;
			}
		}

		// Figure out default level for debug visualization
		m_adaptiveQualityDefaultLevel = 0;
		for ( int i = 0; i < m_adaptiveQualityRenderScaleArray.Count; i++ )
		{
			if ( m_adaptiveQualityRenderScaleArray[ i ] >= 1.0f )
			{
				m_adaptiveQualityDefaultLevel = i;
				break;
			}
		}
		m_nAdaptiveQualityLevel = m_adaptiveQualityDefaultLevel;

		m_adaptiveQualityNumLevels = m_adaptiveQualityRenderScaleArray.Count;

		// Spew to log file
		if ( Application.isPlaying )
		{
			string outputString = "[Valve Camera] Adaptive Quality:\n";
			for ( int i = 1; i < m_adaptiveQualityRenderScaleArray.Count; i++ )
			{
				outputString += i + ". ";
				outputString += " " + ( int )( VRSettings.eyeTextureWidth * m_adaptiveQualityRenderScaleArray[ i ] ) + "x" + ( int )( VRSettings.eyeTextureHeight * m_adaptiveQualityRenderScaleArray[ i ] );
				outputString += " " + m_adaptiveQualityRenderScaleArray[ i ];

				if ( i == m_adaptiveQualityDefaultLevel )
				{
					outputString += " (Default)";
				}
				if ( i == 0 )
				{
					outputString += " (Interleaved reprojection hint)";
				}
				outputString += "\n";
			}
			Debug.Log( outputString );
		}
	}

	[NonSerialized] private int m_nLastQualityFrameCount = -1;
	void UpdateAdaptiveQuality()
	{
		if ( !m_adaptiveQualityEnabled )
		{
			if ( VRSettings.enabled )
			{
				if ( VRSettings.renderScale != 1.0f )
					VRSettings.renderScale = 1.0f;

				if ( VRSettings.renderViewportScale != 1.0f )
					VRSettings.renderViewportScale = 1.0f;
			}

			return;
		}

		if ( m_nLastQualityFrameCount == Time.frameCount )
			return;
		m_nLastQualityFrameCount = Time.frameCount;

		float flRenderTargetScale = m_adaptiveQualityRenderScaleArray[ m_adaptiveQualityNumLevels - 1 ];

		// Add latest timing to ring buffer
		int nRingBufferSize = m_adaptiveQualityRingBuffer.GetLength( 0 );
		m_nAdaptiveQualityRingBufferPos = ( m_nAdaptiveQualityRingBufferPos + 1 ) % nRingBufferSize;
		m_adaptiveQualityRingBuffer[ m_nAdaptiveQualityRingBufferPos ] = VRStats.gpuTimeLastFrame;

		int nOldQualityLevel = m_nAdaptiveQualityLevel;
		float flSingleFrameMs = ( VRDevice.refreshRate > 0.0f ) ? ( 1000.0f / VRDevice.refreshRate ) : ( 1000.0f / 90.0f ); // Assume 90 fps

		// Render low res means adaptive quality needs to scale back target to free up gpu cycles
		bool bRenderLowRes = false;
		if ( Valve.VRRenderingPackage.OpenVR.Compositor != null )
		{
			bRenderLowRes = Valve.VRRenderingPackage.OpenVR.Compositor.ShouldAppRenderWithLowResources();
		}

		// Thresholds
		float flQualityTargetScale = bRenderLowRes ? 0.75f : 1.0f;
		float flLowThresholdMs = 0.7f * flSingleFrameMs * flQualityTargetScale;
		float flExtrapolationThresholdMs = 0.85f * flSingleFrameMs * flQualityTargetScale;
		float flHighThresholdMs = 0.9f * flSingleFrameMs * flQualityTargetScale;

		// Get latest 3 frames
		float flFrameMinus0 = m_adaptiveQualityRingBuffer[ ( m_nAdaptiveQualityRingBufferPos - 0 + nRingBufferSize ) % nRingBufferSize ];
		float flFrameMinus1 = m_adaptiveQualityRingBuffer[ ( m_nAdaptiveQualityRingBufferPos - 1 + nRingBufferSize ) % nRingBufferSize ];
		float flFrameMinus2 = m_adaptiveQualityRingBuffer[ ( m_nAdaptiveQualityRingBufferPos - 2 + nRingBufferSize ) % nRingBufferSize ];

		// Always drop 2 levels except when dropping from level 2
		int nQualityLevelDropTarget = ( nOldQualityLevel == 2 ) ? 1 : ( nOldQualityLevel - 2 );

		// Rapidly reduce quality 2 levels if last frame was critical
		if ( Time.frameCount >= m_nAdaptiveQualityFrameCountLastChanged + 2 + 1 )
		{
			if ( flFrameMinus0 > flHighThresholdMs )
			{
				int nNewLevel = Mathf.Clamp( nQualityLevelDropTarget, 0, m_adaptiveQualityNumLevels - 1 );
				if ( nNewLevel != nOldQualityLevel )
				{
					//Debug.Log( "CRITICAL DROP m_nAdaptiveQualityLevel " + nNewLevel + ". Last frames = " + flFrameMinus2 + "ms, " + flFrameMinus1 + "ms, " + flFrameMinus0 + "ms > " + flCriticalThresholdMs + "\n" );
					m_nAdaptiveQualityLevel = nNewLevel;
					m_nAdaptiveQualityFrameCountLastChanged = Time.frameCount;
					return;
				}
			}
		}

		// Rapidly reduce quality 2 levels if last 3 frames are expensive
		if ( Time.frameCount >= m_nAdaptiveQualityFrameCountLastChanged + 2 + 3 )
		{
			if ( ( flFrameMinus0 > flHighThresholdMs ) &&
				 ( flFrameMinus1 > flHighThresholdMs ) &&
				 ( flFrameMinus2 > flHighThresholdMs ) )
			{
				int nNewLevel = Mathf.Clamp( nQualityLevelDropTarget, 0, m_adaptiveQualityNumLevels - 1 );
				if ( nNewLevel != nOldQualityLevel )
				{
					//Debug.Log( "MAX DROP m_nAdaptiveQualityLevel " + nNewLevel + ". Last frames = " + flFrameMinus2 + "ms, " + flFrameMinus1 + "ms, " + flFrameMinus0 + "ms > " + flHighThresholdMs + "\n" );
					m_nAdaptiveQualityLevel = nNewLevel;
					m_nAdaptiveQualityFrameCountLastChanged = Time.frameCount;
				}
			}
		}

		// Predict next frame's cost using linear extrapolation: max( frame-1 to frame+1, frame-2 to frame+1 )
		if ( Time.frameCount >= m_nAdaptiveQualityFrameCountLastChanged + 2 + 2 )
		{
			if ( flFrameMinus0 > flExtrapolationThresholdMs )
			{
				float flDelta = flFrameMinus0 - flFrameMinus1;

				// Use frame-2 if it's available
				if ( Time.frameCount >= m_nAdaptiveQualityFrameCountLastChanged + 2 + 3 )
				{
					float flDelta2 = ( flFrameMinus0 - flFrameMinus2 ) * 0.5f;
					flDelta = Mathf.Max( flDelta, flDelta2 );
				}

				if ( ( flFrameMinus0 + flDelta ) > flHighThresholdMs )
				{
					int nNewLevel = Mathf.Clamp( nQualityLevelDropTarget, 0, m_adaptiveQualityNumLevels - 1 );
					if ( nNewLevel != nOldQualityLevel )
					{
						//Debug.Log( "PREDICTIVE DROP m_nAdaptiveQualityLevel " + nNewLevel + ". Last frames = " + flFrameMinus2 + "ms, " + flFrameMinus1 + "ms, " + flFrameMinus0 + "ms > " + flHighThresholdMs + "\n" );
						m_nAdaptiveQualityLevel = nNewLevel;
						m_nAdaptiveQualityFrameCountLastChanged = Time.frameCount;
					}
				}
			}
		}

		// Increase quality if last 3 frames are cheap
		if ( Time.frameCount >= m_nAdaptiveQualityFrameCountLastChanged + 2 + 3 )
		{
			if ( ( flFrameMinus0 < flLowThresholdMs ) &&
				 ( flFrameMinus1 < flLowThresholdMs ) &&
				 ( flFrameMinus2 < flLowThresholdMs ) )
			{
				int nNewLevel = Mathf.Clamp( nOldQualityLevel + 1, 0, m_adaptiveQualityNumLevels - 1 );
				if ( nNewLevel != nOldQualityLevel )
				{
					//Debug.Log( "MIN INCREASE m_nAdaptiveQualityLevel " + nNewLevel + ". Last frames = " + flFrameMinus2 + "ms, " + flFrameMinus1 + "ms, " + flFrameMinus0 + "ms < " + flLowThresholdMs + "\n" );
					m_nAdaptiveQualityLevel = nNewLevel;
					m_nAdaptiveQualityFrameCountLastChanged = Time.frameCount;
				}
			}
		}

		// Debug code to roll through each level every frame
		//m_nAdaptiveQualityLevel = ( Time.frameCount ) % m_adaptiveQualityNumLevels;

		int nAdaptiveQualityLevel = m_nAdaptiveQualityLevel;

		// Debug code to override quality level
		if ( s_bAdaptiveQualityVROverride )
		{
			s_nAdaptiveQualityVROverride = Mathf.Clamp( s_nAdaptiveQualityVROverride, 0, m_adaptiveQualityNumLevels - 1 );
			nAdaptiveQualityLevel = s_nAdaptiveQualityVROverride;
		}

		nAdaptiveQualityLevel = Mathf.Clamp( nAdaptiveQualityLevel, 0, m_adaptiveQualityNumLevels - 1 );

		// Force on interleaved reprojection for bin 0 which is just a replica of bin 1 with reprojection enabled
		float flAdditionalViewportScale = 1.0f;
		if ( ( Valve.VRRenderingPackage.OpenVR.Compositor != null ) &&
			 ( Valve.VRRenderingPackage.OpenVR.System != null ) &&
			 ( !IsDisplayOnDesktop() ) )
		{
			if ( nAdaptiveQualityLevel == 0 )
			{
				if ( m_bInterleavedReprojectionEnabled )
				{
					if ( flFrameMinus0 < ( flSingleFrameMs * 0.85f ) )
					{
						m_bInterleavedReprojectionEnabled = false;
					}
				}
				else
				{
					if ( flFrameMinus0 > ( flSingleFrameMs * 0.925f ) )
					{
						m_bInterleavedReprojectionEnabled = true;
					}
				}
			}
			else
			{
				m_bInterleavedReprojectionEnabled = false;
			}

			Valve.VRRenderingPackage.OpenVR.Compositor.ForceInterleavedReprojectionOn( m_bInterleavedReprojectionEnabled );
		}
		else
		{
			// Not running in direct mode! Interleaved reprojection not supported, so scale down the viewport
			if ( nAdaptiveQualityLevel == 0 )
			{
				flAdditionalViewportScale = 0.8f;
			}
		}

		if ( VRSettings.enabled )
		{
			VRSettings.renderScale = flRenderTargetScale;
			VRSettings.renderViewportScale = ( m_adaptiveQualityRenderScaleArray[ nAdaptiveQualityLevel ] / flRenderTargetScale ) * flAdditionalViewportScale;
			//Debug.Log( "VRSettings.renderScale " + VRSettings.renderScale + " VRSettings.renderViewportScale " + VRSettings.renderViewportScale + "\n\n" );
		}

		Shader.SetGlobalInt( "g_nNumBins", m_adaptiveQualityNumLevels );
		Shader.SetGlobalInt( "g_nDefaultBin", m_adaptiveQualityDefaultLevel );
		Shader.SetGlobalInt( "g_nCurrentBin", nAdaptiveQualityLevel );
		Shader.SetGlobalInt( "g_nLastFrameInBudget", m_bInterleavedReprojectionEnabled || ( VRStats.gpuTimeLastFrame > flSingleFrameMs ) ? 0 : 1 );
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	[NonSerialized] private bool m_bFailedToPackLastTime = false;
	bool AutoPackLightsIntoShadowTexture()
	{
		// World's stupidest sheet packer:
		//    1. Sort all lights from largest to smallest
		//    2. In a left->right, top->bottom pattern, fill quads until you reach the edge of the texture
		//    3. Move position to x=0, y=bottomOfFirstTextureInThisRow
		//    4. Goto 2.
		// Yes, this will produce holes as the quads shrink, but it's good enough for now. I'll work on this more later to fill the gaps.

		// Sort all lights from largest to smallest
		ValveRealtimeLight.s_allLights.Sort(
			delegate( ValveRealtimeLight vl1, ValveRealtimeLight vl2 )
			{
				int nCompare = 0;
				bool bCastShadows1 = vl1.CastsShadows();
				bool bCastShadows2 = vl2.CastsShadows();
				if ( bCastShadows1 && bCastShadows2 )
				{
					// Sort shadow-casting lights by shadow resolution
					nCompare = vl2.m_shadowResolution.CompareTo( vl1.m_shadowResolution ); // Sort by shadow size
				}
				else
				{
					// Shadow-casting lights first
					nCompare = bCastShadows2.CompareTo( bCastShadows1 );
				}

				if ( nCompare == 0 ) // Same, so sort by range to stabilize sort results
				{
					nCompare = vl2.m_cachedLight.range.CompareTo( vl1.m_cachedLight.range ); // Sort by shadow size
				}

				if ( nCompare == 0 ) // Still same, so sort by instance ID to stabilize sort results
				{
					nCompare = vl2.GetInstanceID().CompareTo( vl1.GetInstanceID() );
				}

				return nCompare;
			}
		);

		// Start filling lights into texture
		int nNumLightsPacked = 0;
		int nCurrentX = 0;
		int nCurrentY = -1;
		int nNextY = 0;
		int nNumPointLightShadowFacesAdded = 0;
		for ( int nLight = 0; nLight < ValveRealtimeLight.s_allLights.Count; nLight++ )
		{
			ValveRealtimeLight vl = ValveRealtimeLight.s_allLights[ nLight ];
			//Light l = vl.m_cachedLight;

			vl.m_bRenderShadowsThisFrame = false;

			if ( !vl.IsEnabled() )
				continue;

			if ( !vl.CastsShadows() )
				continue;

			nNumLightsPacked++;
			if ( nNumLightsPacked > MAX_LIGHTS )
				break;

			// Check if first texture is too wide
			if ( nCurrentY == -1 )
			{
				if ( ( vl.m_shadowResolution > m_shadowDepthTexture.width ) || ( vl.m_shadowResolution > m_shadowDepthTexture.height ) )
				{
					Debug.LogError( "ERROR! Valve shadow packer ran out of space in the " + m_shadowDepthTexture.width + "x" + m_shadowDepthTexture.height + " texture!\n\n" );
					m_bFailedToPackLastTime = true;
					return false;
				}
			}

			// Goto next scanline
			if ( ( nCurrentY == -1 ) || ( ( nCurrentX + vl.m_shadowResolution ) > m_shadowDepthTexture.width ) )
			{
				nCurrentX = 0;
				nCurrentY = nNextY;
				nNextY += vl.m_shadowResolution;
			}

			// Check if we've run out of space
			if ( ( nCurrentY + vl.m_shadowResolution ) > m_shadowDepthTexture.height )
			{
				Debug.LogError( "ERROR! Valve shadow packer ran out of space in the " + m_shadowDepthTexture.width + "x" + m_shadowDepthTexture.height + " texture!\n\n" );
				m_bFailedToPackLastTime = true;
				return false;
			}

			// Save location to light
			vl.m_shadowX[ nNumPointLightShadowFacesAdded ] = nCurrentX;
			vl.m_shadowY[ nNumPointLightShadowFacesAdded ] = nCurrentY;
			vl.m_bRenderShadowsThisFrame = true;

			// Move ahead
			nCurrentX += vl.m_shadowResolution;

			//Debug.Log( "Sheet packer: " + vl.m_cachedLight.name + " " + nNumPointLightShadowFacesAdded + " ( " + vl.m_shadowX[ nNumPointLightShadowFacesAdded ] + ", " + vl.m_shadowY[ nNumPointLightShadowFacesAdded ] + " ) " + vl.m_shadowResolution + "\n\n" );

			// Point lights require 6 fake spotlights for now
			if ( vl.m_cachedLight.type == LightType.Point )
			{
				nNumPointLightShadowFacesAdded++;
				if ( nNumPointLightShadowFacesAdded < 6 )
				{
					nLight--;
				}
				else
				{
					nNumPointLightShadowFacesAdded = 0;
				}
			}
		}

		if ( m_bFailedToPackLastTime )
		{
			m_bFailedToPackLastTime = false;
			Debug.Log( "SUCCESS! Valve shadow packer can now fit all lights into the " + m_shadowDepthTexture.width + "x" + m_shadowDepthTexture.height + " texture!\n\n" );
		}

		return ( nNumLightsPacked == 0 ) ? false : true;
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	void CullLightsAgainstCameraFrustum()
	{
		//Debug.Log( "CullLightsAgainstCameraFrustum()\n\n" );

		if ( !m_shadowCamera )
		{
			Debug.LogWarning( "ERROR! m_shadowCamera == null!\n" );
			return;
		}

		// Get camera
		Camera camera = gameObject.GetComponent< Camera >();

		#if ( UNITY_EDITOR )
		{
			if ( !EditorApplication.isPlaying )
			{
				if ( m_editorCamera && m_cullLightsFromEditorCamera )
				{
					// Cull from editor camera
					camera = m_editorCamera;
				}
			}
		}
		#endif

		// Calculate camera frustum planes
		Plane[] cameraFrustumPlanes = GeometryUtility.CalculateFrustumPlanes( camera );

		for ( int nLight = 0; nLight < ValveRealtimeLight.s_allLights.Count; nLight++ )
		{
			ValveRealtimeLight vl = ValveRealtimeLight.s_allLights[ nLight ];
			Light l = vl.m_cachedLight;

			// Skip disabled lights
			vl.m_bInCameraFrustum = true; // Set to true so this doesn't affect the vlIsEnabled() call below
			if ( !vl.IsEnabled() )
				continue;

			// Don't cull in editor scene window
			#if ( UNITY_EDITOR )
			{
				if ( !EditorApplication.isPlaying )
				{
					if ( !m_cullLightsInSceneEditor )
					{
						continue;
					}
				}
			}
			#endif

			// Init to false
			vl.m_bInCameraFrustum = false;

			if ( l.type == LightType.Directional )
			{
				// Directional lights are always in frustum
				vl.m_bInCameraFrustum = true;
			}

			if ( l.type == LightType.Point )
			{
				// AABB
				Bounds pointLightBounds = new Bounds( l.transform.position, new Vector3( l.range * 2.0f, l.range * 2.0f, l.range * 2.0f ) );
				if ( GeometryUtility.TestPlanesAABB( cameraFrustumPlanes, pointLightBounds ) )
				{
					// Passed the AABB test
					vl.m_bInCameraFrustum = true;

					Vector3 vPosition = l.transform.position;

					// Disable the light if the sphere is on the back side of any of the camera frustum planes
					for ( int nPlane = 0; nPlane < cameraFrustumPlanes.Length; nPlane++ )
					{
						float flDistanceToLight = cameraFrustumPlanes[ nPlane ].GetDistanceToPoint( vPosition );
						if ( flDistanceToLight < -l.range )
						{
							// Light is on the back side of this frustum plane, so disable
							vl.m_bInCameraFrustum = false;
							break;
						}
					}
				}
			}

			if ( l.type == LightType.Spot )
			{
				Transform lightTransform = l.transform;
				Vector3 vLightPosition = lightTransform.position;
				Vector3 vLightForward = lightTransform.forward;
				float flLightRange = l.range;

				// AABB
				Vector3 vMidPosition = vLightPosition + ( vLightForward * flLightRange * 0.5f );
				Bounds pointLightBounds = new Bounds( vMidPosition, new Vector3( flLightRange, flLightRange, flLightRange ) );
				if ( GeometryUtility.TestPlanesAABB( cameraFrustumPlanes, pointLightBounds ) )
				{
					Vector3 vLightRight = lightTransform.right;
					Vector3 vLightUp = lightTransform.up;
					float flSpotAngle = l.spotAngle;
					
					// Passed the AABB test
					vl.m_bInCameraFrustum = true;

					// Generate 6 points on cone and disable the light if all points are on the back side of any camera frustum plane
					float flHorizontalDistance = Mathf.Tan( flSpotAngle * Mathf.Deg2Rad * 0.5f ) * flLightRange;

					Vector3[] vPositions = new Vector3[ 6 ];
					vPositions[ 0 ] = vLightPosition; // Tip of cone
					vPositions[ 1 ] = vLightPosition + ( vLightForward * flLightRange ); // End of cone down light vector
					vPositions[ 2 ] = vPositions[ 1 ] + ( vLightRight * flHorizontalDistance ); // Point just outside rim of cone
					vPositions[ 3 ] = vPositions[ 1 ] - ( vLightRight * flHorizontalDistance ); // Point just outside rim of cone
					vPositions[ 4 ] = vPositions[ 1 ] + ( vLightUp * flHorizontalDistance ); // Point just outside rim of cone
					vPositions[ 5 ] = vPositions[ 1 ] - ( vLightUp * flHorizontalDistance ); // Point just outside rim of cone

					for ( int nPlane = 0; nPlane < cameraFrustumPlanes.Length; nPlane++ )
					{
						bool bFoundPointOnFrontSide = false;
						for ( int nPoint = 0; nPoint < vPositions.Length; nPoint++ )
						{
							if ( cameraFrustumPlanes[ nPlane ].GetDistanceToPoint( vPositions[ nPoint ] ) > 0.0f )
							{
								bFoundPointOnFrontSide = true;
								break;
							}
						}

						if ( !bFoundPointOnFrontSide )
						{
							// Cull this light
							//Debug.Log( "Point cull " + l.name + "\n\n" );
							vl.m_bInCameraFrustum = false;
							break;
						}
					}
				}
			}
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	// Render shadows
	//---------------------------------------------------------------------------------------------------------------------------------------------------
	[NonSerialized] private int m_nLastRenderedFrameCount = -1;
	void RenderShadowBuffer()
	{
		//Debug.Log( ( EditorApplication.isPlaying ? "" : "UNITY_EDITOR " ) + "RenderShadowBuffer() " + this.name + "\n\n" );

		if ( m_nLastRenderedFrameCount == Time.frameCount )
			return;
		m_nLastRenderedFrameCount = Time.frameCount;
		//Debug.Log( "RenderShadowBuffer() Time.frameCount=" + Time.frameCount + "\n\n" );

		if ( !m_shadowCamera )
		{
			Debug.LogWarning( "ERROR! m_shadowCamera == null!\n" );
			return;
		}

		if ( !m_shadowDepthTexture )
		{
			Debug.LogWarning( "ERROR! m_shadowDepthTexture == null!\n" );
			return;
		}

		// Pack all shadow quads into the texture
		if ( !AutoPackLightsIntoShadowTexture() )
		{
			// No shadowing lights found, so skip all rendering
			return;
		}

		// Set render target
		m_shadowCamera.targetTexture = m_shadowDepthTexture;

		// Clear the entire render target
		m_shadowCamera.pixelRect = new Rect( 0.0f, 0.0f, m_shadowCamera.targetTexture.width, m_shadowCamera.targetTexture.height );
		m_shadowCamera.clearFlags = CameraClearFlags.Depth;
		m_shadowCamera.cullingMask = 0;
		m_shadowCamera.RenderWithShader( m_shaderCastShadows, "DO_NOT_RENDER" );
		m_shadowCamera.clearFlags = CameraClearFlags.Nothing;
		m_shadowCamera.cullingMask = ~0;

		// Render each light's shadow buffer into a subrect of the shared depth texture
		int nNumPointLightShadowFacesAdded = 0;
		for ( int nLight = 0; nLight < ValveRealtimeLight.s_allLights.Count; nLight++ )
		{
			ValveRealtimeLight vl = ValveRealtimeLight.s_allLights[ nLight ];
			Light l = vl.m_cachedLight;

			if ( !vl.IsEnabled() )
				continue;

			if ( !vl.CastsShadows() )
				continue;

			if ( !vl.m_bRenderShadowsThisFrame )
				continue;

			//Debug.Log( "Shadowing spotlight: '" + l.name + "'\n\n" );

			// Set viewport
			m_shadowCamera.pixelRect = new Rect( vl.m_shadowX[ nNumPointLightShadowFacesAdded ], vl.m_shadowY[ nNumPointLightShadowFacesAdded ], vl.m_shadowResolution, vl.m_shadowResolution );

			// Get transform
			Quaternion originalRotate = l.transform.rotation;
			if ( l.type == LightType.Point )
			{
				// Point lights are just 6 fake spotlights for now, so rotate the camera to each face
				if ( nNumPointLightShadowFacesAdded < 4 )
				{
					l.transform.Rotate( l.transform.up.normalized, 90.0f * nNumPointLightShadowFacesAdded, Space.World );
				}
				else
				{
					l.transform.Rotate( l.transform.right.normalized, 90.0f + ( 180.0f * ( nNumPointLightShadowFacesAdded - 4 ) ), Space.World );
				}
			}

			// Set transform
			//m_shadowCamera.cameraType = CameraType.Game;
			m_shadowCamera.aspect = 1.0f;
			m_shadowCamera.orthographic = false;
			m_shadowCamera.nearClipPlane = vl.m_shadowNearClipPlane;
			m_shadowCamera.farClipPlane = l.range;
			m_shadowCamera.fieldOfView = l.spotAngle;
			m_shadowCamera.transform.position = l.transform.position;
			m_shadowCamera.transform.rotation = l.transform.rotation;
			m_shadowCamera.cullingMask = vl.m_shadowCastLayerMask;
			m_shadowCamera.useOcclusionCulling = vl.m_useOcclusionCullingForShadows;

			// Override some values for directional lights
			if ( l.type == LightType.Directional )
			{
				m_shadowCamera.nearClipPlane = DIRECTIONAL_LIGHT_PULLBACK_DISTANCE;
				m_shadowCamera.farClipPlane = m_shadowCamera.nearClipPlane + vl.m_directionalLightShadowRange;

				m_shadowCamera.fieldOfView = Mathf.Rad2Deg * Mathf.Tan( vl.m_directionalLightShadowRadius / m_shadowCamera.nearClipPlane );

				m_shadowCamera.transform.position = new Vector3( l.transform.position.x - ( l.transform.forward.normalized.x * DIRECTIONAL_LIGHT_PULLBACK_DISTANCE ),
																 l.transform.position.y - ( l.transform.forward.normalized.y * DIRECTIONAL_LIGHT_PULLBACK_DISTANCE ),
																 l.transform.position.z - ( l.transform.forward.normalized.z * DIRECTIONAL_LIGHT_PULLBACK_DISTANCE ) );
			}

			if ( l.type == LightType.Point )
			{
				m_shadowCamera.fieldOfView = 90.0f;
			}

			// Create and save transform for shader constants
			Matrix4x4 matScaleBias = Matrix4x4.identity;
			matScaleBias.m00 = 0.5f;
			matScaleBias.m11 = 0.5f;
			matScaleBias.m22 = 0.5f;
			matScaleBias.m03 = 0.5f;
			matScaleBias.m13 = 0.5f;
			matScaleBias.m23 = 0.5f;

			Matrix4x4 matTile = Matrix4x4.identity;
			matTile.m00 = ( float )( vl.m_shadowResolution ) / ( float )m_shadowDepthTexture.width;
			matTile.m11 = ( float )( vl.m_shadowResolution ) / ( float )m_shadowDepthTexture.height;
			matTile.m03 = ( float )vl.m_shadowX[ nNumPointLightShadowFacesAdded ] / ( float )m_shadowDepthTexture.width;
			matTile.m13 = ( float )vl.m_shadowY[ nNumPointLightShadowFacesAdded ] / ( float )m_shadowDepthTexture.height;

			vl.m_shadowTransform[ nNumPointLightShadowFacesAdded ] = matTile * matScaleBias * m_shadowCamera.projectionMatrix * m_shadowCamera.worldToCameraMatrix;
			vl.m_lightCookieTransform[ nNumPointLightShadowFacesAdded ] = matScaleBias * m_shadowCamera.projectionMatrix * m_shadowCamera.worldToCameraMatrix;

			// Set shader constants
			Shader.SetGlobalVector( "g_vLightDirWs", new Vector4( l.transform.forward.normalized.x, l.transform.forward.normalized.y, l.transform.forward.normalized.z ) );

			// Render
			m_shadowCamera.RenderWithShader( m_shaderCastShadows, "RenderType" );

			// Point lights require 6 fake spotlights for now
			if ( l.type == LightType.Point )
			{
				// Reset rotation
				l.transform.rotation = originalRotate;

				// Move to next face
				nNumPointLightShadowFacesAdded++;
				if ( nNumPointLightShadowFacesAdded < 6 )
				{
					nLight--;
				}
				else
				{
					nNumPointLightShadowFacesAdded = 0;
				}
			}
		}

		// Flush
		ValveGLFlushIfNotReprojecting();
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	[NonSerialized] private int m_nWarnedTooManyLights = 0;
	[NonSerialized] private Vector4[] g_vLightColor = new Vector4[ MAX_LIGHTS ];
	[NonSerialized] private Vector4[] g_vLightPosition_flInvRadius = new Vector4[ MAX_LIGHTS ];
	[NonSerialized] private Vector4[] g_vLightDirection = new Vector4[ MAX_LIGHTS ];
	[NonSerialized] private Vector4[] g_vLightShadowIndex_vLightParams = new Vector4[ MAX_LIGHTS ];
	[NonSerialized] private Vector4[] g_vLightFalloffParams = new Vector4[ MAX_LIGHTS ];
	[NonSerialized] private Vector4[] g_vSpotLightInnerOuterConeCosines = new Vector4[ MAX_LIGHTS ];
	[NonSerialized] private Vector4[] g_vShadowMinMaxUv = new Vector4[ MAX_LIGHTS ];
	[NonSerialized] private Matrix4x4[] g_matWorldToShadow = new Matrix4x4[ MAX_LIGHTS ];
	[NonSerialized] private Matrix4x4[] g_matWorldToLightCookie = new Matrix4x4[ MAX_LIGHTS ];
	void UpdateLightConstants()
	{
		int g_nNumLights = 0;
		int nNumLightsIncludingTooMany = 0;

		bool bFoundShadowingPointLight = false;
		int nNumPointLightShadowFacesAdded = 0;
		for ( int nLight = 0; nLight < ValveRealtimeLight.s_allLights.Count; nLight++ )
		{
			ValveRealtimeLight vl = ValveRealtimeLight.s_allLights[ nLight ];
			Light l = vl.m_cachedLight;

			if ( !vl.IsEnabled() )
				continue;

			if ( l.type == LightType.Directional )
			{
				nNumLightsIncludingTooMany++;
				if ( nNumLightsIncludingTooMany > MAX_LIGHTS )
					continue;

				float flIntensity = ( l.intensity <= 1.0f ) ? l.intensity : l.intensity * l.intensity;
				g_vLightColor[ g_nNumLights ] = new Vector4( l.color.linear.r * flIntensity, l.color.linear.g * flIntensity, l.color.linear.b * flIntensity );
				g_vLightPosition_flInvRadius[ g_nNumLights ] = new Vector4( l.transform.position.x - ( l.transform.forward.normalized.x * DIRECTIONAL_LIGHT_PULLBACK_DISTANCE ),
																			l.transform.position.y - ( l.transform.forward.normalized.y * DIRECTIONAL_LIGHT_PULLBACK_DISTANCE ),
																			l.transform.position.z - ( l.transform.forward.normalized.z * DIRECTIONAL_LIGHT_PULLBACK_DISTANCE ),
																			-1.0f );
				g_vLightDirection[ g_nNumLights ] = new Vector4( l.transform.forward.normalized.x, l.transform.forward.normalized.y, l.transform.forward.normalized.z );
				g_vLightShadowIndex_vLightParams[ g_nNumLights ] = new Vector4( 0, 0, 1, 1 );
				g_vLightFalloffParams[ g_nNumLights ] = new Vector4( 0.0f, 0.0f, float.MaxValue );
				g_vSpotLightInnerOuterConeCosines[ g_nNumLights ] = new Vector4( 0.0f, -1.0f, 1.0f );

				if ( ( l.shadows != LightShadows.None ) && ( vl.m_bRenderShadowsThisFrame ) )
				{
					g_vLightShadowIndex_vLightParams[ g_nNumLights ].x = 1; // Enable shadows
					g_matWorldToShadow[ g_nNumLights ] = vl.m_shadowTransform[ nNumPointLightShadowFacesAdded ].transpose;
					g_vShadowMinMaxUv[ g_nNumLights ] = new Vector4( 0.0f, 0.0f, 1.0f, 1.0f );
				}

				g_nNumLights++;
			}

			if ( l.type == LightType.Point )
			{
				nNumLightsIncludingTooMany++;
				if ( nNumLightsIncludingTooMany > MAX_LIGHTS )
					continue;

				float flIntensity = ( l.intensity <= 1.0f ) ? l.intensity : l.intensity * l.intensity;
				g_vLightColor[ g_nNumLights ] = new Vector4( l.color.linear.r * flIntensity, l.color.linear.g * flIntensity, l.color.linear.b * flIntensity );
				g_vLightPosition_flInvRadius[ g_nNumLights ] = new Vector4( l.transform.position.x, l.transform.position.y, l.transform.position.z, 1.0f / l.range );
				g_vLightDirection[ g_nNumLights ] = new Vector4( 0.0f, 0.0f, 0.0f );
				g_vLightShadowIndex_vLightParams[ g_nNumLights ] = new Vector4( 0, 0, 1, 1 );
				g_vLightFalloffParams[ g_nNumLights ] = new Vector4( 1.0f, 0.0f, l.range * l.range );
				g_vSpotLightInnerOuterConeCosines[ g_nNumLights ] = new Vector4( 0.0f, -1.0f, 1.0f );

				// Point lights require 6 fake spotlights for now
				if ( ( l.shadows != LightShadows.None ) && ( vl.m_bRenderShadowsThisFrame ) )
				{
					bFoundShadowingPointLight = true;

					Quaternion originalRotate = l.transform.rotation;
					if ( nNumPointLightShadowFacesAdded < 4 )
					{
						l.transform.Rotate( l.transform.up.normalized, 90.0f * nNumPointLightShadowFacesAdded, Space.World );
					}
					else
					{
						l.transform.Rotate( l.transform.right.normalized, 90.0f + ( 180.0f * ( nNumPointLightShadowFacesAdded - 4 ) ), Space.World );
					}

					// Replace some values above to create the 6 fake spotlights
					g_vLightDirection[ g_nNumLights ] = new Vector4( l.transform.forward.normalized.x, l.transform.forward.normalized.y, l.transform.forward.normalized.z );
					g_vLightShadowIndex_vLightParams[ g_nNumLights ].x = 1; // Enable shadows
					g_vLightShadowIndex_vLightParams[ g_nNumLights ].y = 2; // Enable per-pixel culling
					g_matWorldToShadow[ g_nNumLights ] = vl.m_shadowTransform[ nNumPointLightShadowFacesAdded ].transpose;
					g_matWorldToLightCookie[ g_nNumLights ] = vl.m_lightCookieTransform[ nNumPointLightShadowFacesAdded ].transpose;
					g_vSpotLightInnerOuterConeCosines[ g_nNumLights ] = new Vector4( 0.0f, 0.574f, 9999999.0f );

					g_vShadowMinMaxUv[ g_nNumLights ] = new Vector4(
						( float )( vl.m_shadowX[ nNumPointLightShadowFacesAdded ] + 1 ) / ( float )m_shadowDepthTexture.width,
						( float )( vl.m_shadowY[ nNumPointLightShadowFacesAdded ] + 1 ) / ( float )m_shadowDepthTexture.height,
						( float )( vl.m_shadowX[ nNumPointLightShadowFacesAdded ] + vl.m_shadowResolution - 1 ) / ( float )m_shadowDepthTexture.width,
						( float )( vl.m_shadowY[ nNumPointLightShadowFacesAdded ] + vl.m_shadowResolution - 1 ) / ( float )m_shadowDepthTexture.height );

					// Debug coloring of each spotlight
					//if ( nNumPointLightShadowFacesAdded == 0 )
					//	g_vLightColor[ g_nNumLights ].Scale( new Vector4( 1.0f, 0.0f, 0.0f, 1.0f ) );
					//else if ( nNumPointLightShadowFacesAdded == 1 )
					//	g_vLightColor[ g_nNumLights ].Scale( new Vector4( 0.0f, 1.0f, 0.0f, 1.0f ) );
					//else if ( nNumPointLightShadowFacesAdded == 2 )
					//	g_vLightColor[ g_nNumLights ].Scale( new Vector4( 0.0f, 0.0f, 1.0f, 1.0f ) );
					//else if ( nNumPointLightShadowFacesAdded == 3 )
					//	g_vLightColor[ g_nNumLights ].Scale( new Vector4( 0.0f, 1.0f, 1.0f, 1.0f ) );
					//else if ( nNumPointLightShadowFacesAdded == 4 )
					//	g_vLightColor[ g_nNumLights ].Scale( new Vector4( 1.0f, 0.0f, 1.0f, 1.0f ) );
					//else if ( nNumPointLightShadowFacesAdded == 5 )
					//	g_vLightColor[ g_nNumLights ].Scale( new Vector4( 1.0f, 1.0f, 0.0f, 1.0f ) );

					// Reset rotation
					l.transform.rotation = originalRotate;

					// Move to next face
					nNumPointLightShadowFacesAdded++;
					if ( nNumPointLightShadowFacesAdded < 6 )
					{
						nLight--;
					}
					else
					{
						nNumPointLightShadowFacesAdded = 0;
					}
				}

				g_nNumLights++;
			}

			if ( l.type == LightType.Spot )
			{
				nNumLightsIncludingTooMany++;
				if ( nNumLightsIncludingTooMany > MAX_LIGHTS )
					continue;
				
				float flIntensity = ( l.intensity <= 1.0f ) ? l.intensity : l.intensity * l.intensity;
				g_vLightColor[ g_nNumLights ] = new Vector4( l.color.linear.r * flIntensity, l.color.linear.g * flIntensity, l.color.linear.b * flIntensity );
				g_vLightPosition_flInvRadius[ g_nNumLights ] = new Vector4( l.transform.position.x, l.transform.position.y, l.transform.position.z, 1.0f / l.range );
				g_vLightDirection[ g_nNumLights ] = new Vector4( l.transform.forward.normalized.x, l.transform.forward.normalized.y, l.transform.forward.normalized.z );
				g_vLightShadowIndex_vLightParams[ g_nNumLights ] = new Vector4( 0, 0, 1, 1 );
				g_vLightFalloffParams[ g_nNumLights ] = new Vector4( 1.0f, 0.0f, l.range * l.range );

				float flInnerConePercent = Mathf.Clamp( vl.m_innerSpotPercent, 0.0f, 100.0f ) / 100.0f;
				float flPhiDot = Mathf.Clamp( Mathf.Cos( l.spotAngle * 0.5f * Mathf.Deg2Rad ), 0.0f, 1.0f ); // outer cone
				float flThetaDot = Mathf.Clamp( Mathf.Cos( l.spotAngle * 0.5f * flInnerConePercent * Mathf.Deg2Rad ), 0.0f, 1.0f ); // inner cone
				g_vSpotLightInnerOuterConeCosines[ g_nNumLights ] = new Vector4( flThetaDot, flPhiDot, 1.0f / Mathf.Max( 0.01f, flThetaDot - flPhiDot ) );

				if ( ( l.shadows != LightShadows.None ) && ( vl.m_bRenderShadowsThisFrame ) )
				{
					g_vLightShadowIndex_vLightParams[ g_nNumLights ].x = 1; // Enable shadows
					g_matWorldToShadow[ g_nNumLights ] = vl.m_shadowTransform[ nNumPointLightShadowFacesAdded ].transpose;
					g_vShadowMinMaxUv[ g_nNumLights ] = new Vector4( 0.0f, 0.0f, 1.0f, 1.0f );
				}

				g_nNumLights++;
			}
		}

		// Warn if too many lights found
		if ( nNumLightsIncludingTooMany > MAX_LIGHTS )
		{
			if ( nNumLightsIncludingTooMany > m_nWarnedTooManyLights )
			{
				Debug.LogError( "ERROR! Found " + nNumLightsIncludingTooMany + " runtime lights! Valve renderer supports up to " + MAX_LIGHTS +
					" active runtime lights at a time!\nDisabling " + ( nNumLightsIncludingTooMany - MAX_LIGHTS ) + " runtime light" +
					( ( nNumLightsIncludingTooMany - MAX_LIGHTS ) > 1 ? "s" : "" ) + "!\n" );
			}
			m_nWarnedTooManyLights = nNumLightsIncludingTooMany;
		}
		else
		{
			if ( m_nWarnedTooManyLights > 0 )
			{
				m_nWarnedTooManyLights = 0;
				Debug.Log( "SUCCESS! Found " + nNumLightsIncludingTooMany + " runtime lights which is within the supported number of lights, " + MAX_LIGHTS + ".\n\n" );
			}
		}

		// Send constants to shaders
		Shader.SetGlobalInt( "g_nNumLights", g_nNumLights );

		// New method for Unity 5.4 to set arrays of constants
		Shader.SetGlobalVectorArray( "g_vLightPosition_flInvRadius", g_vLightPosition_flInvRadius );
		Shader.SetGlobalVectorArray( "g_vLightColor", g_vLightColor );
		Shader.SetGlobalVectorArray( "g_vLightDirection", g_vLightDirection );
		Shader.SetGlobalVectorArray( "g_vLightShadowIndex_vLightParams", g_vLightShadowIndex_vLightParams );
		Shader.SetGlobalVectorArray( "g_vLightFalloffParams", g_vLightFalloffParams );
		Shader.SetGlobalVectorArray( "g_vSpotLightInnerOuterConeCosines", g_vSpotLightInnerOuterConeCosines );
		Shader.SetGlobalVectorArray( "g_vShadowMinMaxUv", g_vShadowMinMaxUv );
		Shader.SetGlobalMatrixArray( "g_matWorldToShadow", g_matWorldToShadow );
		Shader.SetGlobalMatrixArray( "g_matWorldToLightCookie", g_matWorldToLightCookie );

		if ( bFoundShadowingPointLight )
		{
			Shader.EnableKeyword( "D_VALVE_SHADOWING_POINT_LIGHTS" );
		}
		else
		{
			Shader.DisableKeyword( "D_VALVE_SHADOWING_POINT_LIGHTS" );
		}

		// Time
		#if ( UNITY_EDITOR )
		{
			Shader.SetGlobalFloat( "g_flTime", Time.realtimeSinceStartup );
			//Debug.Log( "Time " + Time.realtimeSinceStartup );
		}
		#else
		{
			Shader.SetGlobalFloat( "g_flTime", Time.timeSinceLevelLoad );
			//Debug.Log( "Time " + Time.timeSinceLevelLoad );
		}
		#endif

		// PCF 3x3 Shadows
		if ( m_shadowDepthTexture )
		{
			float flTexelEpsilonX = 1.0f / m_shadowDepthTexture.width;
			float flTexelEpsilonY = 1.0f / m_shadowDepthTexture.height;
			Vector4 g_vShadow3x3PCFTerms0 = new Vector4( 20.0f / 267.0f, 33.0f / 267.0f, 55.0f / 267.0f, 0.0f );
			Vector4 g_vShadow3x3PCFTerms1 = new Vector4( flTexelEpsilonX, flTexelEpsilonY, -flTexelEpsilonX, -flTexelEpsilonY );
			Vector4 g_vShadow3x3PCFTerms2 = new Vector4( flTexelEpsilonX, flTexelEpsilonY, 0.0f, 0.0f );
			Vector4 g_vShadow3x3PCFTerms3 = new Vector4( -flTexelEpsilonX, -flTexelEpsilonY, 0.0f, 0.0f );

			Shader.SetGlobalVector( "g_vShadow3x3PCFTerms0", g_vShadow3x3PCFTerms0 );
			Shader.SetGlobalVector( "g_vShadow3x3PCFTerms1", g_vShadow3x3PCFTerms1 );
			Shader.SetGlobalVector( "g_vShadow3x3PCFTerms2", g_vShadow3x3PCFTerms2 );
			Shader.SetGlobalVector( "g_vShadow3x3PCFTerms3", g_vShadow3x3PCFTerms3 );
		}

		Shader.SetGlobalFloat( "g_flValveGlobalVertexScale", m_hideAllValveMaterials ? 0.0f : 1.0f );
		Shader.SetGlobalInt( "g_bIndirectLightmaps", m_indirectLightmapsOnly ? 1 : 0 );
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------------
	[NonSerialized] private bool m_isDisplayOnDesktopCached = false;
	[NonSerialized] private bool m_isDisplayOnDesktop = true;
	private bool IsDisplayOnDesktop()
	{
		if ( !m_isDisplayOnDesktopCached )
		{
			if ( Valve.VRRenderingPackage.OpenVR.System != null )
			{
				m_isDisplayOnDesktop = Valve.VRRenderingPackage.OpenVR.System.IsDisplayOnDesktop();
				m_isDisplayOnDesktopCached = true;
			}
		}

		return m_isDisplayOnDesktop;
	}
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------
#if ( UNITY_EDITOR )
class ValveSceneAutoRendering : EditorWindow
{
	public static bool s_bSceneAutoRender = false;

	private static string s_keyName = "Valve_SceneAutoRenderingEnabled";
	static ValveSceneAutoRendering()
	{
		s_bSceneAutoRender = EditorPrefs.GetBool( s_keyName, s_bSceneAutoRender );
	}

	[MenuItem( "Valve/Shader Dev/Enable Scene Auto-Rendering", true, 1 )]
	static bool ValidateRenderingOn()
	{
		return !s_bSceneAutoRender;
	}

	[MenuItem( "Valve/Shader Dev/Disable Scene Auto-Rendering", true, 2 )]
	static bool ValidateRenderingOff()
	{
		return s_bSceneAutoRender;
	}

	[MenuItem( "Valve/Shader Dev/Enable Scene Auto-Rendering", false, 1 )]
	static void RenderingOn()
	{
		ToggleRendering();
	}

	[MenuItem( "Valve/Shader Dev/Disable Scene Auto-Rendering", false, 2 )]
	static void RenderingOff()
	{
		ToggleRendering();
	}

	static void ToggleRendering()
	{
		if ( !s_bSceneAutoRender )
		{
			s_bSceneAutoRender = true;
		}
		else
		{
			s_bSceneAutoRender = false;
		}

		EditorPrefs.SetBool( s_keyName, s_bSceneAutoRender );
	}
}
#endif

//---------------------------------------------------------------------------------------------------------------------------------------------------
#if ( UNITY_EDITOR )
[CustomEditor( typeof( ValveCamera ) )]
public class ValveCameraInspector : Editor
{
	public override void OnInspectorGUI()
	{
		DrawDefaultInspector();

		ValveCamera valveCamera = target as ValveCamera;

		//for ( int i = 0; i < Camera.allCameras.Length; i++ )
		//{
		//	GUILayout.Label( "Camera " + i + " \"" + Camera.allCameras[ i ].name + "\"" );
		//}
		//EditorGUILayout.Space();

		if ( valveCamera.m_hideAllValveMaterials )
		{
			EditorGUILayout.HelpBox( "WARNING! Unity is still drawing all of the geometry using Valve shaders, but we are discarding the geometry after the vertex shader! Uncheck this before saving scene!", MessageType.Warning, true );
		}

		if ( valveCamera.m_shadowDepthTexture )
		{
			EditorGUILayout.Space();

			// Disabled lights
			GUILayout.Label( "Disabled Lights:" );
			int nNumLightsFound = 0;
			for ( int nLight = 0; nLight < ValveRealtimeLight.s_allLights.Count; nLight++ )
			{
				ValveRealtimeLight vl = ValveRealtimeLight.s_allLights[ nLight ];
				Light l = vl.m_cachedLight;

				if ( vl.IsEnabled() )
					continue;

				nNumLightsFound++;
				GUILayout.Label( "   " + nNumLightsFound + ". " + l.type + ": \"" + l.name + "\"" );
			}

			if ( nNumLightsFound == 0 )
			{
				GUILayout.Label( "   None" );
			}
			EditorGUILayout.Space();

			// Non-Shadow-Casting Lights
			GUILayout.Label( "Non-Shadow-Casting Lights:" );
			nNumLightsFound = 0;
			for ( int nLight = 0; nLight < ValveRealtimeLight.s_allLights.Count; nLight++ )
			{
				ValveRealtimeLight vl = ValveRealtimeLight.s_allLights[ nLight ];
				Light l = vl.m_cachedLight;

				if ( !vl.IsEnabled() )
					continue;

				if ( vl.CastsShadows() )
					continue;

				nNumLightsFound++;
				GUILayout.Label( "   " + nNumLightsFound + ". " + l.type + ": " + "Range( " + l.range + " ) " + ( l.type == LightType.Spot ? "FOV( " : "" ) +
								 ( l.type == LightType.Spot ? l.spotAngle.ToString() : "" ) + ( l.type == LightType.Spot ? " ) " : "" ) + "\"" + l.name + "\"" );
			}

			if ( nNumLightsFound == 0 )
			{
				GUILayout.Label( "   None" );
			}
			EditorGUILayout.Space();

			// Shadow-Casting Lights
			GUILayout.Label( "Shadow-Casting Lights:" );
			nNumLightsFound = 0;
			for ( int nLight = 0; nLight < ValveRealtimeLight.s_allLights.Count; nLight++ )
			{
				ValveRealtimeLight vl = ValveRealtimeLight.s_allLights[ nLight ];
				Light l = vl.m_cachedLight;

				if ( !vl.IsEnabled() )
					continue;

				if ( !vl.CastsShadows() )
					continue;

				nNumLightsFound++;
				if ( l.type == LightType.Directional )
				{
					GUILayout.Label( "   " + nNumLightsFound + ". " + l.type + ": " + vl.m_shadowResolution + "x" + vl.m_shadowResolution +
									 " ZRange( " + vl.m_directionalLightShadowRange + " )" + " Radius( " + vl.m_directionalLightShadowRadius + " ) - " + "\"" + l.name + "\"" );
				}
				else
				{
					GUILayout.Label( "   " + nNumLightsFound + ". " + l.type + ": " + vl.m_shadowResolution + "x" + vl.m_shadowResolution +
									 " ZRange( " + vl.m_shadowNearClipPlane + " - " + l.range + " )" + " FOV( " + l.spotAngle + " ) - " + "\"" + l.name + "\"" );
				}
			}

			if ( nNumLightsFound == 0 )
			{
				GUILayout.Label( "   None" );
			}
			EditorGUILayout.Space();

			// Shadow texture
			if ( true )
			{
				System.Globalization.NumberFormatInfo nfi = new System.Globalization.CultureInfo( "en-US", false ).NumberFormat;
				nfi.NumberDecimalDigits = 0;
				GUILayout.Label( "Shadow Texture - Resolution( " + valveCamera.m_shadowDepthTexture.width + "x" + valveCamera.m_shadowDepthTexture.height + " ) " +
								 ( valveCamera.m_shadowDepthTexture.width * valveCamera.m_shadowDepthTexture.height ).ToString( "N", nfi ) + " pixels" );
				//GUILayout.Label( "Format: " + valveCamera.m_shadowDepthTexture.format );
				//GUILayout.Label( "Filter Mode: " + valveCamera.m_shadowDepthTexture.filterMode );
				//GUILayout.Label( "Name: " + valveCamera.m_shadowDepthTexture.name );

				float flPadding = 5.0f;
				float flWidth = 350.0f;
				float flHeight = flWidth * ( ( float )( valveCamera.m_shadowDepthTexture.height ) / ( float )( valveCamera.m_shadowDepthTexture.width ) );
				Rect outerRect = GUILayoutUtility.GetRect( flWidth + ( flPadding * 2.0f ), flHeight + ( flPadding * 2.0f ), GUILayout.ExpandWidth( false ), GUILayout.ExpandHeight( false ) );
				outerRect.x = Mathf.Max( 0.0f, ( Screen.width - outerRect.width ) * 0.5f - 10.0f );

				Rect innerRect = outerRect;
				innerRect.width -= flPadding;
				innerRect.x += flPadding;
				innerRect.height -= flPadding;
				innerRect.y += flPadding;
				GUI.Box( innerRect, "" );

				if ( nNumLightsFound > 0 )
				{
					Rect textureRect = innerRect;
					textureRect.xMin += flPadding;
					textureRect.yMin += flPadding;
					textureRect.xMax -= flPadding;
					textureRect.yMax -= flPadding;
					EditorGUI.DrawPreviewTexture( textureRect, valveCamera.m_shadowDepthTexture, valveCamera.m_materialShadowVis );
				}
			}
		}

		Repaint();
	}
}
#endif
