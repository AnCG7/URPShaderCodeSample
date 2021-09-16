Shader "Lakehani/URP/Lighting/Banded"
{
    Properties
    {
        _LightStep("Light Step",float) = 50
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
            };

            CBUFFER_START(UnityPerMaterial)
            half _LightStep;
            CBUFFER_END

            //更像是一个卡通的光照的梯度效果
            half LightingBanded(half3 lightDirWS, half3 normalWS, half lightStep)
            {
                half NdotL = saturate(dot(normalWS, lightDirWS));
                half lightBandsMultiplier = lightStep / 256;
                half lightBandsAdditive = lightStep / 2;
                half banded = (floor((NdotL * 256 + lightBandsAdditive) / lightStep)) * lightBandsMultiplier;
                return banded;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normalWS=TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;

                half bandedNdotL = LightingBanded(light.direction,normalize(IN.normalWS),_LightStep);

                half3 bandedColor = bandedNdotL * lightColor;

                half4 totlaColor = half4(bandedColor.rgb,1);
                return totlaColor;
            }

            ENDHLSL
        }
    }
}
