//在顶点着色器中实现的冯氏光照模型叫做Gouraud着色(Gouraud Shading)，而不是冯氏着色(Phong Shading)
//该例子为冯氏着色
//Phong着色与Phong高光不同，着色模型是一个完整的效果混合，高光只是其中一项

Shader "Lakehani/URP/Lighting/Phong"
{
    Properties
    {
        _BaseColor ("BaseColor", Color) = (1,1,1,1)
        _SpecularColor ("SpecularColor", Color) = (1,1,1,1)
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
            half4 _BaseColor;
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
                half3 normalWS = normalize(IN.normalWS);
                half3 viewWS =  SafeNormalize(IN.viewWS);

                half3 specularColor = LightingSpecularPhong(lightColor, light.direction, normalWS,viewWS, _SpecularColor, smoothness);
                half3 diffuseColor = LightingLambert(lightColor,light.direction,normalWS) * _BaseColor.rgb;
                half3 ambientColor = unity_AmbientSky.rgb * _BaseColor.rgb;

                half4 totalColor = half4(diffuseColor + specularColor + ambientColor,1);

                return totalColor;

            }



            ENDHLSL
        }
    }
}
