Shader "Lakehani/URP/Base/VertexAnimation"
{
    Properties
    {
        _BaseColor("BaseColor", Color) = (1,1,1,1)
        _Speed("Speed",Float) = 1.0
        _MaxHeight("Max Height",Float) = 1.0
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
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _BaseColor;
            float _Speed;
            float _MaxHeight;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
 
                //用Sin和Cos等周期函数来实现循环往复的数据，然后偏移顶点坐标的位置，例子使用偏移世界坐标系Y轴实现弹跳效果
                float3 offsetPos = positionWS;
                offsetPos += abs(sin(_Time.y * _Speed) * float3(0,_MaxHeight,0));

                OUT.positionHCS = TransformWorldToHClip(offsetPos);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return _BaseColor;
            }
            ENDHLSL
        }
    }
}
