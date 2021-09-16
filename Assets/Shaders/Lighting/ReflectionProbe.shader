Shader "Lakehani/URP/Lighting/ReflectionProbe"
{
    Properties
    {
        _Smoothness ("Smoothness",  Range(0,1)) = 1.0
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
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 viewWS : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
            float _Smoothness;
            CBUFFER_END

            half3 ReflectionProbe(float3 viewDirWS, float3 normalWS ,half smoothness)
            {
                 half roughness= 1-smoothness;
                 half mip = PerceptualRoughnessToMipmapLevel(roughness);//因为粗糙度和mipmap的LOD关系在真实情况下不是线性的,所以使用这个函数来计算
                 float3 reflectVec = reflect(-viewDirWS, normalWS);
                 return DecodeHDREnvironment(SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVec, mip), unity_SpecCube0_HDR);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.viewWS = GetWorldSpaceViewDir(positionWS);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normalWS = normalize(IN.normalWS);
                half3 viewWS = SafeNormalize(IN.viewWS);
                half3 reflection = ReflectionProbe(viewWS,normalWS ,_Smoothness); 
                return half4(reflection.rgb,1);
            }

            ENDHLSL
        }
    }
}
