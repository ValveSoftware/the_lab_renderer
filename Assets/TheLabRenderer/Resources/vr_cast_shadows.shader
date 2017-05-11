

// Copyright (c) Valve Corporation, All rights reserved. ======================================================================================================
// Modified to include  alpha cutout and alpha blended shadows
// Also replaced the biasing function with Unity's own implementation
// of Ignacio Castaño's suggestions
// Simon Windmill 03/19/2017

Shader  "Valve/Internal/vr_cast_shadows"
{

	SubShader
	{
		Tags { "RenderType" = "Opaque" "PerformanceChecks" = "False" }
		LOD 300

		Pass
		{
		 	Name "ValveShadowCaster"
			Tags { "LightMode" = "ForwardBase" }


			ZWrite On
			ZTest LEqual
			 ColorMask 0
			Blend Off
			Offset 2.5, 1 // http://docs.unity3d.com/Manual/SL-CullAndDepth.html

			CGPROGRAM
			 #pragma target 5.0
			#pragma only_renderers d3d11
			//#pragma multi_compile_shadowcaster

			// Valve custom dynamic combos
			 #pragma multi_compile _ MATRIX_PALETTE_SKINNING_1BONE

			#pragma vertex MainVs
			#pragma fragment MainPs

			#include "UnityCG.cginc"
		 	#include "../Shaders/vr_matrix_palette_skinning.cginc"

			struct VertexInput
			{

				float4 vPositionOs : POSITION;
		 		float3 vNormalOs : NORMAL;

				#if ( MATRIX_PALETTE_SKINNING )
					float4 vBoneIndices : COLOR;
				 #endif
			};

			struct VertexOutput
			{

				float4 vPositionPs : SV_POSITION;
			};

		 	VertexOutput MainVs(VertexInput i)
			{
				VertexOutput o;


				#if ( MATRIX_PALETTE_SKINNING )

				 {
					MatrixPaletteSkinning(i.vPositionOs.xyzw, i.vBoneIndices.xyzw);





				}
				#endif

				 o.vPositionPs = UnityClipSpaceShadowCasterPos(i.vPositionOs.xyz, i.vNormalOs);
				o.vPositionPs = UnityApplyLinearShadowBias(o.vPositionPs);

				 return o;
			}

			float4 MainPs(VertexOutput i) : SV_Target
			{
				return float4(0.0, 0.0, 0.0,  0.0);
			}
			ENDCG
		}
	}

	SubShader
	{
		Tags{ "RenderType" = "TransparentCutout" "PerformanceChecks" = "False" }
	 	LOD 300

		Pass
		{
			Name "ValveShadowCaster"
			Tags{ "LightMode" = "ForwardBase" }

			ZWrite On
		 	ZTest LEqual
			ColorMask 0
			Blend Off
			Offset 2.5, 1 // http://docs.unity3d.com/Manual/SL-CullAndDepth.html

			 CGPROGRAM
			#pragma target 5.0
			#pragma only_renderers d3d11
			//#pragma multi_compile_shadowcaster

			// Valve  custom dynamic combos
			#pragma multi_compile _ MATRIX_PALETTE_SKINNING_1BONE

			#pragma vertex MainVs
			#pragma fragment MainPs

			 #include "UnityCG.cginc"
			#include "../Shaders/vr_matrix_palette_skinning.cginc"

			struct VertexInput
			{
				 float4 vPositionOs : POSITION;
				float3 vNormalOs : NORMAL;
				float2 uv0 : TEXCOORD0;

			#if ( MATRIX_PALETTE_SKINNING )
		 		float4 vBoneIndices : COLOR;
			#endif
			};

			struct VertexOutput
			{
				 float4 vPositionPs : SV_POSITION;
				float2 uv0 : TEXCOORD0;
			};

			sampler2D _MainTex;
			fixed _Cutoff;
		
			VertexOutput MainVs(VertexInput i)
			{
				VertexOutput o;

			#if ( MATRIX_PALETTE_SKINNING )
			 {
				MatrixPaletteSkinning(i.vPositionOs.xyzw, i.vBoneIndices.xyzw);
			}
			#endif

				o.vPositionPs =  UnityClipSpaceShadowCasterPos(i.vPositionOs.xyz, i.vNormalOs);
				o.vPositionPs = UnityApplyLinearShadowBias(o.vPositionPs);

				o.uv0 =  i.uv0;

				return o;
			}

			float4 MainPs(VertexOutput i) : SV_Target
			{
				 half alpha = tex2D(_MainTex, i.uv0).a;
				clip(alpha - _Cutoff);

				return float4(0.0, 0.0, 0.0, 0.0);

			}
			 ENDCG
		}
	}

	SubShader
	{
		Tags{ "RenderType" = "Transparent" "PerformanceChecks" = "False" }
		LOD 300

		Pass
		{
		 	Name "ValveShadowCaster"
			Tags{ "LightMode" = "ForwardBase" }

			ZWrite On
			ZTest LEqual
			 ColorMask 0
			Blend Off
			Offset 2.5, 1 // http://docs.unity3d.com/Manual/SL-CullAndDepth.html

			CGPROGRAM
			 #pragma target 5.0
			#pragma only_renderers d3d11
			//#pragma multi_compile_shadowcaster

			// Valve custom dynamic combos
			 #pragma multi_compile _ MATRIX_PALETTE_SKINNING_1BONE

			#pragma vertex MainVs
			#pragma fragment MainPs

			#include "UnityCG.cginc"
		 	#include "../Shaders/vr_matrix_palette_skinning.cginc"

			struct VertexInput
			{
				float4 vPositionOs : POSITION;
		 		float3 vNormalOs : NORMAL;
				float2 uv0 : TEXCOORD0;

		#if ( MATRIX_PALETTE_SKINNING )
				float4 vBoneIndices :  TEXCOORD3;
		#endif

				fixed4 color : COLOR;
			};

			struct VertexOutput
			{
				 float4 vPositionPs : SV_POSITION;
				float2 uv0 : TEXCOORD0;

				fixed4 color : COLOR;
			};

			struct  VertexOutputClip
			{
				UNITY_VPOS_TYPE vpos : VPOS;
				float2 uv0 : TEXCOORD0;
				fixed4  color : COLOR;
			};

			sampler2D _MainTex;
			sampler3D _DitherMaskLOD;
			half4 _Color;
			fixed  _Cutoff;

			VertexOutput MainVs(VertexInput i)
			{


				VertexOutput o;

			#if ( MATRIX_PALETTE_SKINNING )
		 	{
				MatrixPaletteSkinning(i.vPositionOs.xyzw, i.vBoneIndices.xyzw);
			}
			#endif
				 o.vPositionPs = UnityClipSpaceShadowCasterPos(i.vPositionOs.xyz, i.vNormalOs);
				o.vPositionPs = UnityApplyLinearShadowBias(o.vPositionPs);

				 o.uv0 = i.uv0;

				o.color = i.color;






				return o;
			}


			float4 MainPs(VertexOutputClip i) :  SV_Target
			{
				half alpha = tex2D(_MainTex, i.uv0).a * _Color.a * i.color.a;







				// magic numbers explained in  http://catlikecoding.com/unity/tutorials/rendering/part-12/
				float dither = tex3D(_DitherMaskLOD, float3(i.vpos.xy * 0.25, alpha * 0.9475)).a;
			 	clip(dither - 0.01);





				return float4(0.0, 0.0, 0.0, 0.0);
			}

			ENDCG
		}
	}
}