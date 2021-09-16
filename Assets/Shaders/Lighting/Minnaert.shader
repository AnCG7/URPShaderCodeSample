/*Minnaert照明模型最初设计用于模拟月球的着色，因此它通常被称为moon shader。
Minnaert适合模拟多孔或纤维状表面，如月球或天鹅绒。这些表面会导致大量光线反向散射。
这一点在纤维主要垂直于表面（如天鹅绒、天鹅绒甚至地毯）的地方尤为明显。
此模拟提供的结果与Oren Nayar非常接近，后者也经常被称为velvet（天鹅绒）或moon着色器。
*/

Shader "Lakehani/URP/Lighting/Minnaert"
{
    Properties
    {
        _Roughness("Roughness",float) = 1
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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
            half _Roughness;
            CBUFFER_END

            //一般用来模拟月亮的光照
            half LightingMinnaert(half3 lightDirWS, half3 normalWS, half3 viewDirWS, half roughness)
            {
                half NdotL = saturate(dot(normalWS, lightDirWS));
                half NdotV = saturate(dot(normalWS, viewDirWS));
                half minnaert = saturate(NdotL * pow(NdotL * NdotV, roughness));
                return minnaert;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS=TransformObjectToWorldNormal(IN.normalOS);
                OUT.viewWS = GetWorldSpaceViewDir(positionWS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                half3 normalWS = normalize(IN.normalWS);
                half3 viewWS = SafeNormalize(IN.viewWS);

                half minnaert = LightingMinnaert(light.direction, normalWS, viewWS, _Roughness);
                
                half3 minnaertColor = minnaert * lightColor;

                half4 totlaColor = half4(minnaertColor.rgb,1);
                return totlaColor;
            }

            ENDHLSL
        }
    }
}
