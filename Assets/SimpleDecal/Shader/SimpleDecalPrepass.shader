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
                uint renderingLayers = GetMeshRenderingLayer();
                return float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
            }
            ENDHLSL
        }
    }
}
