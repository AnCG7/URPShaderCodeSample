Shader "Lakehani/URP/Base/TangentCheck"
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
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                half4 color           : COLOR;
            };
            //切线和副法线向量用于法线贴图。在 Unity 中，只有切线向量存储在顶点中，副法线来自法线和切线值(叉乘)
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.color = IN.tangentOS * 0.5 + 0.5; //把 -1到1 映射到 0到1
                return OUT;
            }
            half4 frag(Varyings IN) : SV_Target
            {
                return IN.color;
            }
            ENDHLSL
        }
    }
}
