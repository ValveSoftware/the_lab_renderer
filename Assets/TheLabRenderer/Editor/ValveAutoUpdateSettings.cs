﻿// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================
//
// Prompt developers to use settings required by this plugin
//
//-------------------------------------------------------------------------------------------------------------------------------------------------------------

using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEditor.Rendering;
using System;
using System.IO;

[InitializeOnLoad]
public class TheLabRenderer_Settings : EditorWindow
{
	const bool forceShow = false; // Set to true to get the dialog to show back up in the case you clicked Ignore All.

	const string ignore = "ignore.";
	const string useRecommended = "Use recommended ({0})";
	const string currentValue = " (current = {0})";

	const string buildTarget = "Build Target";
	const string showUnitySplashScreen = "Show Unity Splashscreen";
	const string defaultIsFullScreen = "Default is Fullscreen";
	const string defaultScreenSize = "Default Screen Size";
	const string runInBackground = "Run In Background";
	const string displayResolutionDialog = "Display Resolution Dialog";
	const string resizableWindow = "Resizable Window";
	const string fullscreenMode = "D3D11 Fullscreen Mode";
	const string visibleInBackground = "Visible In Background";
	const string renderingPath = "Rendering Path";
	const string colorSpace = "Color Space";
	const string gpuSkinning = "GPU Skinning";
	const string shadowCascades = "Shadow Cascades";
	const string pixelLightCount = "Pixel Light Count";
#if false // skyboxes are currently broken
	const string singlePassStereoRendering = "Single-Pass Stereo Rendering";
#endif

	const BuildTarget recommended_BuildTarget = BuildTarget.StandaloneWindows64;
	const bool recommended_ShowUnitySplashScreen = false;
	const bool recommended_DefaultIsFullScreen = false;
	const int recommended_DefaultScreenWidth = 1024;
	const int recommended_DefaultScreenHeight = 768;
	const bool recommended_RunInBackground = true;
	const ResolutionDialogSetting recommended_DisplayResolutionDialog = ResolutionDialogSetting.HiddenByDefault;
	const bool recommended_ResizableWindow = true;
	const D3D11FullscreenMode recommended_FullscreenMode = D3D11FullscreenMode.FullscreenWindow;
	const bool recommended_VisibleInBackground = true;
	const RenderingPath recommended_RenderPath = RenderingPath.Forward;
	const ColorSpace recommended_ColorSpace = ColorSpace.Linear;
	const bool recommended_GpuSkinning = true;
	const int recommended_shadowCascades = 1;
	const int recommended_pixelLightCount = 99;
#if false
	const bool recommended_SinglePassStereoRendering = true;
#endif

	static TheLabRenderer_Settings window;

	static TheLabRenderer_Settings()
	{
		EditorApplication.update += Update;
	}

	static bool showUnitySplashScreenPlayerSetting{
		get{
			#if UNITY_5_4
				return PlayerSettings.showUnitySplashScreen;
			#else
				return PlayerSettings.SplashScreen.show;
			#endif
		}
		set{
			#if UNITY_5_4
				PlayerSettings.showUnitySplashScreen = value;
			#else
				PlayerSettings.SplashScreen.show = value;
			#endif
		}
	}

	static RenderingPath renderingPathPlayerSetting{
		get{
			#if UNITY_5_4
				return PlayerSettings.renderingPath;
			#else
				TierSettings tierSettings = EditorGraphicsSettings.GetTierSettings(EditorUserBuildSettings.selectedBuildTargetGroup, Graphics.activeTier);
				return tierSettings.renderingPath;
			#endif
		}
		set{
			#if UNITY_5_4
				PlayerSettings.renderingPath = value;
			#else
				foreach(GraphicsTier tier in (GraphicsTier[])Enum.GetValues(typeof(GraphicsTier))){
					TierSettings tierSettings = EditorGraphicsSettings.GetTierSettings(EditorUserBuildSettings.selectedBuildTargetGroup, tier);
					tierSettings.renderingPath = value;
					EditorGraphicsSettings.SetTierSettings(EditorUserBuildSettings.selectedBuildTargetGroup, tier, tierSettings);
				}
			#endif
		}
	}

	static void Update()
	{
		bool show =
			(!EditorPrefs.HasKey(ignore + buildTarget) &&
				EditorUserBuildSettings.activeBuildTarget != recommended_BuildTarget) ||
			(!EditorPrefs.HasKey(ignore + showUnitySplashScreen) &&
				showUnitySplashScreenPlayerSetting != recommended_ShowUnitySplashScreen) ||
			(!EditorPrefs.HasKey(ignore + defaultIsFullScreen) &&
				PlayerSettings.defaultIsFullScreen != recommended_DefaultIsFullScreen) ||
			(!EditorPrefs.HasKey(ignore + defaultScreenSize) &&
				(PlayerSettings.defaultScreenWidth != recommended_DefaultScreenWidth ||
				PlayerSettings.defaultScreenHeight != recommended_DefaultScreenHeight)) ||
			(!EditorPrefs.HasKey(ignore + runInBackground) &&
				PlayerSettings.runInBackground != recommended_RunInBackground) ||
			(!EditorPrefs.HasKey(ignore + displayResolutionDialog) &&
				PlayerSettings.displayResolutionDialog != recommended_DisplayResolutionDialog) ||
			(!EditorPrefs.HasKey(ignore + resizableWindow) &&
				PlayerSettings.resizableWindow != recommended_ResizableWindow) ||
			(!EditorPrefs.HasKey(ignore + fullscreenMode) &&
				PlayerSettings.d3d11FullscreenMode != recommended_FullscreenMode) ||
			(!EditorPrefs.HasKey(ignore + visibleInBackground) &&
				PlayerSettings.visibleInBackground != recommended_VisibleInBackground) ||
			(!EditorPrefs.HasKey(ignore + renderingPath) &&
				renderingPathPlayerSetting != recommended_RenderPath) ||
			(!EditorPrefs.HasKey(ignore + colorSpace) &&
				PlayerSettings.colorSpace != recommended_ColorSpace) ||
			(!EditorPrefs.HasKey(ignore + gpuSkinning) &&
				PlayerSettings.gpuSkinning != recommended_GpuSkinning) ||
			(!EditorPrefs.HasKey(ignore + shadowCascades) &&
				QualitySettings.shadowCascades != recommended_shadowCascades) ||
			(!EditorPrefs.HasKey(ignore + pixelLightCount) &&
				QualitySettings.pixelLightCount != recommended_pixelLightCount) ||
#if false
			(!EditorPrefs.HasKey(ignore + singlePassStereoRendering) &&
				PlayerSettings.singlePassStereoRendering != recommended_SinglePassStereoRendering) ||
#endif
			forceShow;

		if (show)
		{
			window = GetWindow<TheLabRenderer_Settings>(true);
			window.minSize = new Vector2(375, 600);
			//window.title = "The Lab Renderer Settings";
		}

		// Switch to native OpenVR support.
		var updated = false;

		if (!PlayerSettings.virtualRealitySupported)
		{
			PlayerSettings.virtualRealitySupported = true;
			updated = true;
		}

		#if UNITY_5_4
		var devices = UnityEditorInternal.VR.VREditor.GetVREnabledDevices(BuildTargetGroup.Standalone);
		#else
		var devices = UnityEditorInternal.VR.VREditor.GetVREnabledDevicesOnTargetGroup(BuildTargetGroup.Standalone);
		#endif
		var hasOpenVR = false;
		foreach (var device in devices)
			if (device.ToLower() == "openvr")
				hasOpenVR = true;

		if (!hasOpenVR)
		{
			string[] newDevices;
			if (updated)
			{
				newDevices = new string[] { "OpenVR" };
			}
			else
			{
				newDevices = new string[devices.Length + 1];
				for (int i = 0; i < devices.Length; i++)
					newDevices[i] = devices[i];
				newDevices[devices.Length] = "OpenVR";
				updated = true;
			}
			#if UNITY_5_4
			UnityEditorInternal.VR.VREditor.SetVREnabledDevices(BuildTargetGroup.Standalone, newDevices);
			#else
			UnityEditorInternal.VR.VREditor.SetVREnabledDevicesOnTargetGroup(BuildTargetGroup.Standalone, newDevices);
			#endif
		}

		if (updated)
			Debug.Log("Switching to native OpenVR support.");

		var dlls = new string[]
		{
			"Plugins/x86/openvr_api.dll",
			"Plugins/x86_64/openvr_api.dll"
		};

		foreach (var path in dlls)
		{
			if (!File.Exists(Application.dataPath + "/" + path))
				continue;

			if (AssetDatabase.DeleteAsset("Assets/" + path))
				Debug.Log("Deleting " + path);
			else
			{
				Debug.Log(path + " in use; cannot delete.  Please restart Unity to complete upgrade.");
			}
		}

		EditorApplication.update -= Update;
	}

	Vector2 scrollPosition;
	bool toggleState;

	string GetResourcePath()
	{
		var ms = MonoScript.FromScriptableObject(this);
		var path = AssetDatabase.GetAssetPath(ms);
		path = Path.GetDirectoryName(path);
		return path.Substring(0, path.Length - "Editor".Length) + "Textures/";
	}

	public void OnGUI()
	{
		//var resourcePath = GetResourcePath();
		//var logo = AssetDatabase.LoadAssetAtPath<Texture2D>(resourcePath + "logo.png");
		//var rect = GUILayoutUtility.GetRect(position.width, 150, GUI.skin.box);
		//if (logo)
		//	GUI.DrawTexture(rect, logo, ScaleMode.ScaleToFit);

		EditorGUILayout.HelpBox("Recommended project settings for The Lab Renderer:", MessageType.Warning);

		scrollPosition = GUILayout.BeginScrollView(scrollPosition);

		int numItems = 0;

		if (!EditorPrefs.HasKey(ignore + buildTarget) &&
			EditorUserBuildSettings.activeBuildTarget != recommended_BuildTarget)
		{
			++numItems;

			GUILayout.Label(buildTarget + string.Format(currentValue, EditorUserBuildSettings.activeBuildTarget));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_BuildTarget)))
			{
				#if UNITY_5_4 || UNITY_5_5
				EditorUserBuildSettings.SwitchActiveBuildTarget(recommended_BuildTarget);
				#else
				EditorUserBuildSettings.SwitchActiveBuildTarget(BuildPipeline.GetBuildTargetGroup(recommended_BuildTarget), recommended_BuildTarget);
				#endif
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + buildTarget, true);
			}

			GUILayout.EndHorizontal();
		}

		if (!EditorPrefs.HasKey(ignore + showUnitySplashScreen) &&
			showUnitySplashScreenPlayerSetting != recommended_ShowUnitySplashScreen)
		{
			++numItems;

			GUILayout.Label(showUnitySplashScreen + string.Format(currentValue, showUnitySplashScreenPlayerSetting));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_ShowUnitySplashScreen)))
			{
				showUnitySplashScreenPlayerSetting = recommended_ShowUnitySplashScreen;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + showUnitySplashScreen, true);
			}

			GUILayout.EndHorizontal();
		}

		if (!EditorPrefs.HasKey(ignore + defaultIsFullScreen) &&
			PlayerSettings.defaultIsFullScreen != recommended_DefaultIsFullScreen)
		{
			++numItems;

			GUILayout.Label(defaultIsFullScreen + string.Format(currentValue, PlayerSettings.defaultIsFullScreen));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_DefaultIsFullScreen)))
			{
				PlayerSettings.defaultIsFullScreen = recommended_DefaultIsFullScreen;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + defaultIsFullScreen, true);
			}

			GUILayout.EndHorizontal();
		}

		if (!EditorPrefs.HasKey(ignore + defaultScreenSize) &&
			(PlayerSettings.defaultScreenWidth != recommended_DefaultScreenWidth ||
			PlayerSettings.defaultScreenHeight != recommended_DefaultScreenHeight))
		{
			++numItems;

			GUILayout.Label(defaultScreenSize + string.Format(" ({0}x{1})", PlayerSettings.defaultScreenWidth, PlayerSettings.defaultScreenHeight));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format("Use recommended ({0}x{1})", recommended_DefaultScreenWidth, recommended_DefaultScreenHeight)))
			{
				PlayerSettings.defaultScreenWidth = recommended_DefaultScreenWidth;
				PlayerSettings.defaultScreenHeight = recommended_DefaultScreenHeight;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + defaultScreenSize, true);
			}

			GUILayout.EndHorizontal();
		}

		if (!EditorPrefs.HasKey(ignore + runInBackground) &&
			PlayerSettings.runInBackground != recommended_RunInBackground)
		{
			++numItems;

			GUILayout.Label(runInBackground + string.Format(currentValue, PlayerSettings.runInBackground));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_RunInBackground)))
			{
				PlayerSettings.runInBackground = recommended_RunInBackground;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + runInBackground, true);
			}

			GUILayout.EndHorizontal();
		}

		if (!EditorPrefs.HasKey(ignore + displayResolutionDialog) &&
			PlayerSettings.displayResolutionDialog != recommended_DisplayResolutionDialog)
		{
			++numItems;

			GUILayout.Label(displayResolutionDialog + string.Format(currentValue, PlayerSettings.displayResolutionDialog));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_DisplayResolutionDialog)))
			{
				PlayerSettings.displayResolutionDialog = recommended_DisplayResolutionDialog;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + displayResolutionDialog, true);
			}

			GUILayout.EndHorizontal();
		}

		if (!EditorPrefs.HasKey(ignore + resizableWindow) &&
			PlayerSettings.resizableWindow != recommended_ResizableWindow)
		{
			++numItems;

			GUILayout.Label(resizableWindow + string.Format(currentValue, PlayerSettings.resizableWindow));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_ResizableWindow)))
			{
				PlayerSettings.resizableWindow = recommended_ResizableWindow;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + resizableWindow, true);
			}

			GUILayout.EndHorizontal();
		}

		if (!EditorPrefs.HasKey(ignore + fullscreenMode) &&
			PlayerSettings.d3d11FullscreenMode != recommended_FullscreenMode)
		{
			++numItems;

			GUILayout.Label(fullscreenMode + string.Format(currentValue, PlayerSettings.d3d11FullscreenMode));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_FullscreenMode)))
			{
				PlayerSettings.d3d11FullscreenMode = recommended_FullscreenMode;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + fullscreenMode, true);
			}

			GUILayout.EndHorizontal();
		}

		if (!EditorPrefs.HasKey(ignore + visibleInBackground) &&
			PlayerSettings.visibleInBackground != recommended_VisibleInBackground)
		{
			++numItems;

			GUILayout.Label(visibleInBackground + string.Format(currentValue, PlayerSettings.visibleInBackground));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_VisibleInBackground)))
			{
				PlayerSettings.visibleInBackground = recommended_VisibleInBackground;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + visibleInBackground, true);
			}

			GUILayout.EndHorizontal();
		}

		if (!EditorPrefs.HasKey(ignore + renderingPath) &&
			renderingPathPlayerSetting != recommended_RenderPath)
		{
			++numItems;

			GUILayout.Label(renderingPath + string.Format(currentValue, renderingPathPlayerSetting));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_RenderPath) + " - required for MSAA"))
			{
				renderingPathPlayerSetting = recommended_RenderPath;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + renderingPath, true);
			}

			GUILayout.EndHorizontal();
		}

		if (!EditorPrefs.HasKey(ignore + colorSpace) &&
			PlayerSettings.colorSpace != recommended_ColorSpace)
		{
			++numItems;

			GUILayout.Label(colorSpace + string.Format(currentValue, PlayerSettings.colorSpace));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_ColorSpace) + " - requires reloading scene"))
			{
				PlayerSettings.colorSpace = recommended_ColorSpace;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + colorSpace, true);
			}

			GUILayout.EndHorizontal();
		}

		if (!EditorPrefs.HasKey(ignore + gpuSkinning) &&
			PlayerSettings.gpuSkinning != recommended_GpuSkinning)
		{
			++numItems;

			GUILayout.Label(gpuSkinning + string.Format(currentValue, PlayerSettings.gpuSkinning));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_GpuSkinning)))
			{
				PlayerSettings.gpuSkinning = recommended_GpuSkinning;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + gpuSkinning, true);
			}

			GUILayout.EndHorizontal();
		}

		if (!EditorPrefs.HasKey(ignore + shadowCascades) &&
			QualitySettings.shadowCascades != recommended_shadowCascades)
		{
			++numItems;

			GUILayout.Label(shadowCascades + string.Format(currentValue, QualitySettings.shadowCascades));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_shadowCascades)))
			{
				QualitySettings.shadowCascades = recommended_shadowCascades;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + shadowCascades, true);
			}

			GUILayout.EndHorizontal();
		}

		if (!EditorPrefs.HasKey(ignore + pixelLightCount) &&
			QualitySettings.pixelLightCount != recommended_pixelLightCount)
		{
			++numItems;

			GUILayout.Label(pixelLightCount + string.Format(currentValue, QualitySettings.pixelLightCount));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_pixelLightCount)))
			{
				QualitySettings.pixelLightCount = recommended_pixelLightCount;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + pixelLightCount, true);
			}

			GUILayout.EndHorizontal();
		}

#if false
		if (!EditorPrefs.HasKey(ignore + singlePassStereoRendering) &&
			PlayerSettings.singlePassStereoRendering != recommended_SinglePassStereoRendering)
		{
			++numItems;

			GUILayout.Label(singlePassStereoRendering + string.Format(currentValue, PlayerSettings.singlePassStereoRendering));

			GUILayout.BeginHorizontal();

			if (GUILayout.Button(string.Format(useRecommended, recommended_SinglePassStereoRendering)))
			{
				PlayerSettings.singlePassStereoRendering = recommended_SinglePassStereoRendering;
			}

			GUILayout.FlexibleSpace();

			if (GUILayout.Button("Ignore"))
			{
				EditorPrefs.SetBool(ignore + singlePassStereoRendering, true);
			}

			GUILayout.EndHorizontal();
		}
#endif

		GUILayout.BeginHorizontal();

		GUILayout.FlexibleSpace();

		if (GUILayout.Button("Clear All Ignores"))
		{
			EditorPrefs.DeleteKey(ignore + buildTarget);
			EditorPrefs.DeleteKey(ignore + showUnitySplashScreen);
			EditorPrefs.DeleteKey(ignore + defaultIsFullScreen);
			EditorPrefs.DeleteKey(ignore + defaultScreenSize);
			EditorPrefs.DeleteKey(ignore + runInBackground);
			EditorPrefs.DeleteKey(ignore + displayResolutionDialog);
			EditorPrefs.DeleteKey(ignore + resizableWindow);
			EditorPrefs.DeleteKey(ignore + fullscreenMode);
			EditorPrefs.DeleteKey(ignore + visibleInBackground);
			EditorPrefs.DeleteKey(ignore + renderingPath);
			EditorPrefs.DeleteKey(ignore + colorSpace);
			EditorPrefs.DeleteKey(ignore + gpuSkinning);
			EditorPrefs.DeleteKey(ignore + shadowCascades);
			EditorPrefs.DeleteKey(ignore + pixelLightCount);
#if false
			EditorPrefs.DeleteKey(ignore + singlePassStereoRendering);
#endif
		}

		GUILayout.EndHorizontal();

		GUILayout.EndScrollView();

		GUILayout.FlexibleSpace();

		GUILayout.BeginHorizontal();

		if (numItems > 0)
		{
			if (GUILayout.Button("Accept All"))
			{
				// Only set those that have not been explicitly ignored.
				if (!EditorPrefs.HasKey(ignore + buildTarget))
					#if UNITY_5_4 || UNITY_5_5
					EditorUserBuildSettings.SwitchActiveBuildTarget(recommended_BuildTarget);
					#else
					EditorUserBuildSettings.SwitchActiveBuildTarget(BuildPipeline.GetBuildTargetGroup(recommended_BuildTarget), recommended_BuildTarget);
					#endif
				if (!EditorPrefs.HasKey(ignore + showUnitySplashScreen))
					showUnitySplashScreenPlayerSetting = recommended_ShowUnitySplashScreen;
				if (!EditorPrefs.HasKey(ignore + defaultIsFullScreen))
					PlayerSettings.defaultIsFullScreen = recommended_DefaultIsFullScreen;
				if (!EditorPrefs.HasKey(ignore + defaultScreenSize))
				{
					PlayerSettings.defaultScreenWidth = recommended_DefaultScreenWidth;
					PlayerSettings.defaultScreenHeight = recommended_DefaultScreenHeight;
				}
				if (!EditorPrefs.HasKey(ignore + runInBackground))
					PlayerSettings.runInBackground = recommended_RunInBackground;
				if (!EditorPrefs.HasKey(ignore + displayResolutionDialog))
					PlayerSettings.displayResolutionDialog = recommended_DisplayResolutionDialog;
				if (!EditorPrefs.HasKey(ignore + resizableWindow))
					PlayerSettings.resizableWindow = recommended_ResizableWindow;
				if (!EditorPrefs.HasKey(ignore + fullscreenMode))
					PlayerSettings.d3d11FullscreenMode = recommended_FullscreenMode;
				if (!EditorPrefs.HasKey(ignore + visibleInBackground))
					PlayerSettings.visibleInBackground = recommended_VisibleInBackground;
				if (!EditorPrefs.HasKey(ignore + renderingPath))
					renderingPathPlayerSetting = recommended_RenderPath;
				if (!EditorPrefs.HasKey(ignore + colorSpace))
					PlayerSettings.colorSpace = recommended_ColorSpace;
				if (!EditorPrefs.HasKey(ignore + gpuSkinning))
					PlayerSettings.gpuSkinning = recommended_GpuSkinning;
				if (!EditorPrefs.HasKey(ignore + shadowCascades))
					QualitySettings.shadowCascades = recommended_shadowCascades;
				if (!EditorPrefs.HasKey(ignore + pixelLightCount))
					QualitySettings.pixelLightCount = recommended_pixelLightCount;
#if false
				if (!EditorPrefs.HasKey(ignore + singlePassStereoRendering))
					PlayerSettings.singlePassStereoRendering = recommended_SinglePassStereoRendering;
#endif

				EditorUtility.DisplayDialog("Accept All", "You made the right choice!", "Ok");

				Close();
			}

			if (GUILayout.Button("Ignore All"))
			{
				if (EditorUtility.DisplayDialog("Ignore All", "Are you sure?", "Yes, Ignore All", "Cancel"))
				{
					// Only ignore those that do not currently match our recommended settings.
					if (EditorUserBuildSettings.activeBuildTarget != recommended_BuildTarget)
						EditorPrefs.SetBool(ignore + buildTarget, true);
					if (showUnitySplashScreenPlayerSetting != recommended_ShowUnitySplashScreen)
						EditorPrefs.SetBool(ignore + showUnitySplashScreen, true);
					if (PlayerSettings.defaultIsFullScreen != recommended_DefaultIsFullScreen)
						EditorPrefs.SetBool(ignore + defaultIsFullScreen, true);
					if (PlayerSettings.defaultScreenWidth != recommended_DefaultScreenWidth ||
						PlayerSettings.defaultScreenHeight != recommended_DefaultScreenHeight)
						EditorPrefs.SetBool(ignore + defaultScreenSize, true);
					if (PlayerSettings.runInBackground != recommended_RunInBackground)
						EditorPrefs.SetBool(ignore + runInBackground, true);
					if (PlayerSettings.displayResolutionDialog != recommended_DisplayResolutionDialog)
						EditorPrefs.SetBool(ignore + displayResolutionDialog, true);
					if (PlayerSettings.resizableWindow != recommended_ResizableWindow)
						EditorPrefs.SetBool(ignore + resizableWindow, true);
					if (PlayerSettings.d3d11FullscreenMode != recommended_FullscreenMode)
						EditorPrefs.SetBool(ignore + fullscreenMode, true);
					if (PlayerSettings.visibleInBackground != recommended_VisibleInBackground)
						EditorPrefs.SetBool(ignore + visibleInBackground, true);
					if (renderingPathPlayerSetting != recommended_RenderPath)
						EditorPrefs.SetBool(ignore + renderingPath, true);
					if (PlayerSettings.colorSpace != recommended_ColorSpace)
						EditorPrefs.SetBool(ignore + colorSpace, true);
					if (PlayerSettings.gpuSkinning != recommended_GpuSkinning)
						EditorPrefs.SetBool(ignore + gpuSkinning, true);
					if (QualitySettings.shadowCascades != recommended_shadowCascades)
						EditorPrefs.SetBool(ignore + shadowCascades, true);
					if (QualitySettings.pixelLightCount != recommended_pixelLightCount)
						EditorPrefs.SetBool(ignore + pixelLightCount, true);
#if false
					if (PlayerSettings.singlePassStereoRendering != recommended_SinglePassStereoRendering)
						EditorPrefs.SetBool(ignore + singlePassStereoRendering, true);
#endif

					Close();
				}
			}
		}
		else if (GUILayout.Button("Close"))
		{
			Close();
		}

		GUILayout.EndHorizontal();
	}
}

