Shader "Lakehani/URP/Lighting/Lightmap"
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

            #pragma multi_compile _ LIGHTMAP_ON

            #pragma vertex vert
            #pragma fragment frag
           

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS : NORMAL;
                float2 lightmapUV    : TEXCOORD1;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.lightmapUV = IN.lightmapUV.xy * unity_LightmapST.xy + unity_LightmapST.zw; //等同于 OUTPUT_LIGHTMAP_UV(IN.lightmapUV, unity_LightmapST, OUT.lightmapUV);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normalWS = normalize(IN.normalWS);
                half3 bakeGI = SampleLightmap(IN.lightmapUV,normalWS);
                return half4(bakeGI.rgb,1);
            }

            ENDHLSL
        }
    }
}
