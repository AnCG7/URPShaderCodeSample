Shader "Lakehani/URP/Base/Transparent"
{
    Properties
    {
        _MainColor("Color",Color)=(1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Transparent"}

        Pass
        {
        
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _MainColor;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return _MainColor;
            }

            ENDHLSL
        }
    }
}
