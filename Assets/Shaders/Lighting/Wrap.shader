Shader "Lakehani/URP/Lighting/Wrap"
{
    Properties
    {
        _Wrap("Wrap",float) = 0.5
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
            half _Wrap;
            CBUFFER_END

            half LightingWrap(half3 lightDirWS,half3 normalWS, half wrap)
            {
                half NL=dot(normalWS,lightDirWS);
                half NLWrap = (NL + wrap)/(1 + wrap);
                return NLWrap;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normalWS=TransformObjectToWorldNormal(IN.normalOS,true);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                half3 diffuseColor = LightingWrap(light.direction,normalize(IN.normalWS),_Wrap) * lightColor;
                half4 totlaColor = half4(diffuseColor.rgb,1);
                return totlaColor;
            }

            ENDHLSL
        }
    }
}
