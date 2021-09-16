//Oren–Nayar反射率模型是 粗糙表面漫反射 的反射率模型。该模型是一种简单的方法，
//这个模型是一个简单的方法来近似光线对粗糙但，仍然是lambertian式。

Shader "Lakehani/URP/Lighting/OrenNayer"
{
    Properties
    {
        _Roughness ("Roughness", Range(0,1)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Geometry"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //注释掉这一行可以看到另一个简单版本的实现
            #pragma shader_feature OrenNayer_Algorithm_Version

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 viewWS : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
            half _Roughness;
            CBUFFER_END

            //原始算法的版本
            half3 LightingOrenNayerAlgorithm(half3 lightColor, half3 lightDirWS, half3 normalWS, half3 viewDirWS,half3 diffuseColor, half roughness)
            {
                //float roughness = tex2D(_RoughnessTex,i.uv).r * roughness;//这里可以采样贴图
                half NL = saturate(dot(normalWS,lightDirWS));
                half NV = saturate(dot(normalWS,viewDirWS));
                half theta2 = roughness * roughness;
                half A = 1 - 0.5 * (theta2 / (theta2 + 0.33));
                half B = 0.45 * (theta2 / (theta2 + 0.09));
                half acosNV = acos(NV);
                half acosNL = acos(NL);
                half alpha = max(acosNV,acosNL);
                half beta =  min(acosNV,acosNL);
                half gamma = length(viewDirWS - normalWS * NV) * length(lightDirWS - normalWS * NL);
                half orenNayer = NL * (A + B * max(0,gamma) * sin(alpha) * tan(beta));
                return orenNayer * diffuseColor * lightColor;
            }

            //简单实现的版本
            half3 LightingOrenNayerSimple(half3 lightColor,half3 lightDirWS, half3 normalWS, half3 viewDirWS, half3 diffuseColor, half roughness)
            {
                half roughnessSqr = roughness * roughness;
                half3 o_n_fraction = roughnessSqr / (roughnessSqr + float3(0.33, 0.13, 0.09));
                half3 oren_nayar = float3(1, 0, 0) + float3(-0.5, 0.17, 0.45) * o_n_fraction;
                half cos_ndotl = saturate(dot(normalWS, lightDirWS));
                half cos_ndotv = saturate(dot(normalWS, viewDirWS));
                half oren_nayar_s = saturate(dot(lightDirWS, viewDirWS)) - cos_ndotl * cos_ndotv;
                oren_nayar_s /= lerp(max(cos_ndotl, cos_ndotv), 1, step(oren_nayar_s, 0));
                half3 oren_nayarColor = diffuseColor * cos_ndotl * (oren_nayar.x + diffuseColor * oren_nayar.y + oren_nayar.z * oren_nayar_s) * lightColor;
                return oren_nayarColor;
            }


            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS =TransformObjectToWorldNormal(IN.normalOS,true);
                OUT.viewWS = GetWorldSpaceNormalizeViewDir(positionWS);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                half3 normalWS = normalize(IN.normalWS);
                half3 viewWS = SafeNormalize(IN.viewWS);

                #ifdef OrenNayer_Algorithm_Version
                    half3 orenNayarColor = LightingOrenNayerAlgorithm(lightColor, light.direction,normalWS, viewWS, half3(1,1,1), _Roughness);
                #else
                    half3 orenNayarColor = LightingOrenNayerSimple(lightColor, light.direction, normalWS, viewWS,half3(1,1,1),_Roughness);
                #endif

                half4 totalColor = half4(orenNayarColor.rgb,1);

                return totalColor;

            }



            ENDHLSL
        }
    }
}
