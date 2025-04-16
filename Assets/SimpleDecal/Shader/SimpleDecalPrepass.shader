/*
    *用来预渲染_DecalRenderingLayerMask，在SimpleDecal.shader中会使用到,用于根据物体的RenderingLayerMask来判断是否需要裁剪
*/

Shader "Lakehani/URP/Effect/SimpleDecalPreRender"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline"}

        Pass
        {
            Name "SimpleDecalPreRenderPass"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            ZWrite On
            Cull Back
            
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
            
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                //unity内置的渲染层信息函数
                uint renderingLayers = GetMeshRenderingLayer();
                return float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
            }
            ENDHLSL
        }
    }
}
