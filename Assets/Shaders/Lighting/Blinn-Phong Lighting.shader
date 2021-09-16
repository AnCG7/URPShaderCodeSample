/*
如果你想获得和Phong(冯氏)着色类似的效果，就必须在使用Blinn-Phong模型时将镜面反光度设置更高一点。通常我们会选择冯氏着色时反光度分量的2到4倍。
我这里因为用了Smoothness参数所以按照常规的 2到4倍并不准确，可以自己去掉Smoothness的计算，尝试一下。
*/
Shader "Lakehani/URP/Lighting/BlinnPhong"
{
    Properties
    {
        _BaseColor ("BaseColor", Color) = (1,1,1,1)
        _SpecularColor ("SpecularColor", Color) = (1,1,1,1)
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
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
            half3 _BaseColor;
            half4 _SpecularColor;
            half _Smoothness;
            CBUFFER_END



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
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                half smoothness = exp2(10 * _Smoothness + 1);
                half3 normalWS = normalize(IN.normalWS);
                half3 viewWS =  SafeNormalize(IN.viewWS);

                half3 specularColor = LightingSpecular(lightColor, light.direction, normalWS, viewWS, _SpecularColor, smoothness);
                half3 diffuseColor = LightingLambert(lightColor,light.direction,normalWS) * _BaseColor;
                half3 ambientColor = unity_AmbientSky.rgb * _BaseColor;
                half4 totalColor = half4(diffuseColor + specularColor + ambientColor,1);

                return totalColor;
            }

            ENDHLSL
        }
    }
}
