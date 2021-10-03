Shader "Lakehani/URP/Base/TextureScrollUV"
{
    Properties
    {
        _BaseColor("BaseColor", Color) = (1,1,1,1)
        _BaseMap("BaseMap", 2D) = "white" {}
        _ScrollXSpeed("X Scroll Speed", Float) = 1
        _ScrollYSpeed("Y Scroll Speed", Float) = 1
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
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 positionHCS  : SV_POSITION;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            float _ScrollXSpeed;
            float _ScrollYSpeed;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                //_Time声明在UnityInput.hlsl有详细注释可以自行查看
                float2 scrollUV = float2(_ScrollXSpeed, _ScrollYSpeed) * _Time.y + OUT.uv;
                OUT.uv = scrollUV;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
            }
            ENDHLSL
        }
    }
}
