Shader "Lakehani/URP/Lighting/ReceiveShadow"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Geometry"}

        Pass
        {
            HLSLPROGRAM

            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #pragma vertex vert
            #pragma fragment frag
            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 positionWS : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionWS = positionWS;
                OUT.positionHCS = TransformWorldToHClip(positionWS);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Light GetMainLight(float4 shadowCoord) 在 Lighting.hlsl
                // half MainLightRealtimeShadow(float4 shadowCoord) 在 Shadows.hlsl
                //因为影子和光照牵扯的比较多,影子本身又和烘培有关系，情况较多，本实例只演示实时阴影的使用方式，由上述2个函数修改而来。
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);//这个转换函数还可以再拆，但是没有必要, 在 Shadows.hlsl 可以自行学习（其实就是多了一个计算阴影级联的宏）
                ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
                half4 shadowParams = GetMainLightShadowParams();
                //实时光的本质还是采样shadow map. _SHADOWS_SOFT 作用发挥在SampleShadowmap函数中，不定义的话没有软阴影
                half shadowAttenuation = SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, false);
                //这里为了方便观察直接用采样结果作为rgb
                half4 baseColor = half4(shadowAttenuation,shadowAttenuation,shadowAttenuation,1);
                return baseColor;
            }

            ENDHLSL
        }
    }
}
