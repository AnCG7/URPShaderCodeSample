//使用Blinn-Phong 作为光照模型来演示多光源的如何操作

Shader "Lakehani/URP/Lighting/MultiLighting"
{
    Properties
    {
        _BaseColor ("BaseColor", Color) = (1,1,1,1)
        _SpecularColor ("SpecularColor", Color) = (1,1,1,1)
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Geometry"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
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
                float3 positionWS:TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
            half3 _BaseColor;
            half4 _SpecularColor;
            half _Smoothness;
            CBUFFER_END



            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionWS = positionWS;
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.viewWS = GetWorldSpaceViewDir(positionWS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                half smoothness = exp2(10 * _Smoothness + 1);
                half3 normalWS = normalize(IN.normalWS);
                half3 viewWS =  SafeNormalize(IN.viewWS);

                half3 diffuseColor = LightingLambert(lightColor,light.direction,normalWS);
                half3 specularColor = LightingSpecular(lightColor, light.direction, normalWS, viewWS, _SpecularColor, smoothness);

                int additionalLightCount = GetAdditionalLightsCount();//获取额外光源数量
                for (int i = 0; i < additionalLightCount; ++i)
                {
                    light = GetAdditionalLight(i, IN.positionWS);//根据index获取额外的光源数据
                    half3 attenuatedLightColor = light.color * light.distanceAttenuation;
                    //叠加漫反射和高光
                    diffuseColor += LightingLambert(attenuatedLightColor, light.direction, normalWS);
                    specularColor += LightingSpecular(attenuatedLightColor, light.direction, normalWS, viewWS, _SpecularColor, smoothness);
                }


                half3 ambientColor = unity_AmbientSky.rgb * _BaseColor;
                half4 totalColor = half4(diffuseColor + specularColor + ambientColor,1);

                return totalColor;
            }

            ENDHLSL
        }
    }
}
