Shader "Lakehani/URP/Base/Fog"
{
    Properties
    {
        _MainColor("Color",Color) = (0,0,0,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Geometry"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float fogFactor : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _MainColor;
            float _FogFactor;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.fogFactor = ComputeFogFactor(OUT.positionHCS.z);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //自带的3中计算雾的宏的类型 FOG_LINEAR、FOG_EXP 、FOG_EXP2 对应于 Lighting->Environment 面板的 Other Settings
                //具体见 ShaderVariablesFunctions.hlsl 的 MixFog 函数
                half3 mixColorAndFog = MixFog(_MainColor.rgb , IN.fogFactor);
                return half4(mixColorAndFog.rgb,1);
            }

            ENDHLSL
        }
    }
}
