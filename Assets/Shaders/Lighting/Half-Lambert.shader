Shader "Lakehani/URP/Lighting/HalfLambert"
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
            };

            half LightingHalfLambert(half3 lightDirWS, half3 normalWS)
            {
                half NdotL = saturate(dot(normalWS, lightDirWS));//范围 0.0 - 1.0
                //_WrapValue 范围为[0.5,1]
                //pow(dot(N,L)*_WrapValue+(1-_WrapValue),2);

                //(NdotL * 0.5 + 0.5) 把亮度映射到0.5 - 1.0 之间,会多一个背光; 2.0这个参数一般都是2.0 不过可以自由调整看看是否合适你想要的效果;
                half halfLambert = pow(NdotL * 0.5 + 0.5,2.0);
                return halfLambert;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normalWS =TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                
                half halfLambert = LightingHalfLambert(light.direction,normalize(IN.normalWS));

                half3 diffuseColor = halfLambert * lightColor;

                half4 totlaColor = half4(diffuseColor.rgb,1);
                return totlaColor;
            }

            ENDHLSL
        }
    }
}
