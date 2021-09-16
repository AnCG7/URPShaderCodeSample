Shader "Lakehani/URP/Base/AlphaTest"
{
    Properties
    {
        _AlphaTestTexture("AlphaTest Texture", 2D) = "white" {}
        _ClipThreshold("Alpha Test Threshold",Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" "Queue"="AlphaTest"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv:TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv:TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _AlphaTestTexture_ST;
            float _ClipThreshold;
            CBUFFER_END

            TEXTURE2D(_AlphaTestTexture);SAMPLER(sampler_AlphaTestTexture);

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.uv = TRANSFORM_TEX(IN.uv, _AlphaTestTexture);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half alpha = SAMPLE_TEXTURE2D(_AlphaTestTexture, sampler_AlphaTestTexture, IN.uv).r;
                //也可以使用 AlphaDiscard 宏，但是需要在头部定义 _ALPHATEST_ON
                //例如：#pragma shader_feature_local_fragment _ALPHATEST_ON
                //具体实现见 ShaderVariablesFunctions.hlsl 
                clip(alpha - _ClipThreshold);
                return half4(1,1,1,1);
            }

            ENDHLSL
        }
    }
}
