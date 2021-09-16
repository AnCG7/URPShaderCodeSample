Shader "Lakehani/URP/Lighting/PhongSpecular"
{
    Properties
    {
        _SpecularColor ("SpecularGloss", Color) = (1,1,1,1)
        _Smoothness ("Smoothness",  Range(0,1)) = 0.5
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
            half4 _SpecularColor;
            half _Smoothness;
            CBUFFER_END

            half3 LightingSpecularPhong(half3 lightColor, half3 lightDir, half3 normal, half3 viewDir, half4 specular, half smoothness)
            {
                half3 reflectDir = normalize(reflect(-lightDir,normal));
                half LdotV = saturate(dot(reflectDir,viewDir));
                half modifier = pow(LdotV, smoothness);
                half3 specularReflection = specular.rgb * modifier;
				return lightColor * specularReflection;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS =TransformObjectToWorldNormal(IN.normalOS);
                OUT.viewWS = GetWorldSpaceViewDir(positionWS);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;

                half smoothness = exp2(10 * _Smoothness + 1);
                half3 specularColor= LightingSpecularPhong(lightColor, light.direction, normalize(IN.normalWS), SafeNormalize(IN.viewWS), _SpecularColor, smoothness);
                half4 totalColor=half4(specularColor.rgb,1);

                return totalColor;

            }



            ENDHLSL
        }
    }
}
