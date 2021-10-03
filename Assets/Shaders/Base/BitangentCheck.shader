Shader "Lakehani/URP/Base/BitangentCheck"
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
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                half4 color           : COLOR;
            };
            //切线和副法线向量用于法线贴图。在 Unity 中，只有切线向量存储在顶点中，双切线来自法线和切线值(叉乘)
            //双切线（有时称为副法线）有兴趣的可以查询 Bitangent 和 Binormal 的区别
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                //IN.tangentOS.xyz是切线方向 ,IN.tangentOS.w 的值为+1或者-1,w 分量进一步决定了取叉乘结果的正方向还是反方向（重点）
                //参考ShaderVariablesFunctions.hlsl的GetVertexNormalInputs函数
                //GetOddNegativeScale() 函数为了mikkts space 兼容，不在意的话不乘它也可以
                float sign = IN.tangentOS.w * GetOddNegativeScale();
                float3 bitangent = cross(IN.normalOS, IN.tangentOS.xyz) * sign;

                OUT.color.xyz = bitangent * 0.5 + 0.5; //把 -1到1 映射到 0到1
                OUT.color.w = 1.0;
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
