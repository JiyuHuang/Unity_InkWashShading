Shader "Custom/InkWash" {

    Properties {
        _Tint("Tint", Color) = (1, 1, 1, 1)
        _MainTex("Albedo", 2D) = "white" {}
        [Gamma] _Metallic("Metallic", Range(0, 1)) = 0
        _Smoothness("Smoothness", Range(0, 1)) = 0.5

        [Header(OutLine)]
		_StrokeColor ("Stroke Color", Color) = (0, 0, 0, 1)
		_OutlineNoise ("Outline Noise Map", 2D) = "white" {}
		_Outline ("Outline", Range(0, 1)) = 0.067
		_OutsideNoiseWidth ("Outside Noise Width", Range(1, 2)) = 1.3
		_MaxOutlineZOffset ("Max Outline Z Offset", Range(0,1)) = 0

        [Header(Brush)]
        _BrushTex("Brush Texture", 2D) = "white" {}
    }

    SubShader {

        Pass {
            Cull Front
            CGPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag

            #include "UnityCG.cginc"

            float _Outline;
            float4 _StrokeColor;
            sampler2D _OutlineNoise;
            half _MaxOutlineZOffset;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };

            v2f Vert(a2v v) {
                float4 burn = tex2Dlod(_OutlineNoise, v.vertex);

                v2f o;
                float3 scaledir = mul((float3x3) UNITY_MATRIX_MV, v.normal);
                scaledir += 0.5;
                scaledir.z = 0.01;
                scaledir = normalize(scaledir);

                float4 position_cs = float4(UnityObjectToViewPos(v.vertex), 1);

                float3 viewDir = normalize(position_cs.xyz);
                float3 offset_pos_cs = position_cs.xyz + viewDir * _MaxOutlineZOffset;

                float linewidth = -position_cs.z / unity_CameraProjection[1].y;
                linewidth = sqrt(linewidth);
                position_cs.xy = offset_pos_cs.xy + scaledir.xy * linewidth * burn.x * _Outline ;
                position_cs.z = offset_pos_cs.z;

                o.pos = mul(UNITY_MATRIX_P, position_cs);

                return o;
            }

            fixed4 Frag(v2f i) : SV_Target {
                fixed4 c = _StrokeColor;
                return c;
            }

            ENDCG
        }

        Pass {
			Cull Front
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			float _Outline;
			float4 _StrokeColor;
			sampler2D _OutlineNoise;
			float _OutsideNoiseWidth;
			half _MaxOutlineZOffset;

			struct a2v
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 texcoord : TEXCOORD0;
			};

			struct v2f
			{
			    float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			v2f vert (a2v v)
			{
				float4 burn = tex2Dlod(_OutlineNoise, v.vertex);

				v2f o = (v2f)0;
				float3 scaledir = mul((float3x3) UNITY_MATRIX_MV, v.normal);
				scaledir += 0.5;
				scaledir.z = 0.01;
				scaledir = normalize(scaledir);

                float4 position_cs = float4(UnityObjectToViewPos(v.vertex), 1);

				float3 viewDir = normalize(position_cs.xyz);
				float3 offset_pos_cs = position_cs.xyz + viewDir * _MaxOutlineZOffset;

				float linewidth = -position_cs.z / unity_CameraProjection[1].y;
				linewidth = sqrt(linewidth);
				position_cs.xy = offset_pos_cs.xy + scaledir.xy * linewidth * burn.y * _Outline * 1.1 * _OutsideNoiseWidth ;
				position_cs.z = offset_pos_cs.z;

				o.pos = mul(UNITY_MATRIX_P, position_cs);

				o.uv = v.texcoord.xy;

				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				// clip random outline here
				fixed4 c = _StrokeColor;
				fixed3 burn = tex2D(_OutlineNoise, i.uv).rgb;
				if (burn.x > 0.5)
					discard;
				return c;
			}
			ENDCG
		}

        Pass {
            Tags {
                "LightMode" = "ForwardBase"
            }

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile _ SHADOWS_SCREEN

            #pragma vertex Vert
            #pragma fragment Frag

            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"

            float4 _Tint;
            sampler2D _MainTex;
			float4 _MainTex_ST;
            float _Smoothness;
            float _Metallic;

            sampler2D _BrushTex;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                SHADOW_COORDS(3)
            };

            v2f Vert(a2v v) {
                v2f i;
                i.pos = UnityObjectToClipPos(v.vertex);
                i.uv = TRANSFORM_TEX(v.uv, _MainTex);
                i.normal = UnityObjectToWorldNormal(v.normal);
                i.worldPos = mul(unity_ObjectToWorld, v.vertex);
                TRANSFER_SHADOW(i);
                return i;
            }

            float4 Frag(v2f i) : SV_TARGET {
                i.normal = normalize(i.normal);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
				float3 albedo = 1;
                float3 specularTint;
				float oneMinusReflectivity;
				albedo = DiffuseAndSpecularFromMetallic(
					albedo, _Metallic, specularTint, oneMinusReflectivity
				);

                UnityLight light;
                light.dir = _WorldSpaceLightPos0.xyz;
                UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
				light.color = _LightColor0.rgb * attenuation;
				light.ndotl = DotClamped(i.normal, light.dir);

				UnityIndirect indirectLight;
				indirectLight.diffuse = max(0, ShadeSH9(float4(i.normal, 1)));
				indirectLight.specular = 0;

                fixed4 color = UNITY_BRDF_PBS(
					albedo, specularTint,
					oneMinusReflectivity, _Smoothness,
					i.normal, viewDir,
					light, indirectLight
				);

                fixed grey = color.r * 0.30 + color.g * 0.59 + color.b * 0.11;
                grey = pow(grey, 0.3);
                grey *= 1 - cos(grey * 3.14);
                fixed brush = tex2D(_BrushTex, i.uv).r;
                grey = grey * brush;

                return fixed4(grey * tex2D(_MainTex, i.uv).rgb * _Tint.rgb, 1);
            }

            ENDCG
        }

        Pass {
			Tags {
				"LightMode" = "ShadowCaster"
			}

			CGPROGRAM

			#pragma target 3.0

			#pragma vertex Vert
			#pragma fragment Frag

            #include "UnityCG.cginc"

            struct a2v {
            	float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            float4 Vert(a2v v) : SV_POSITION {
            	return UnityApplyLinearShadowBias(UnityClipSpaceShadowCasterPos(v.vertex.xyz, v.normal));
            }

            half4 Frag() : SV_TARGET {
            	return 0;
            }

			ENDCG
		}
    }
}
