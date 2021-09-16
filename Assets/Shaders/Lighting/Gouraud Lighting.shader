//在顶点着色器中实现的冯氏光照模型叫做Gouraud着色(Gouraud Shading)，而不是冯氏着色(Phong Shading)
//不得不提起总和Gouraud着色对比的另一种着色，Flat着色
//Flat本质使用面法线计算,对应模型建模中的平直着色（顶点法线方向都等于面法线方向）。
//当然如果模型是平滑着色（顶点法线是周围面法线的平均值方向）的话可以在片段着色器使用这个求面法线normalize( cross(ddy(positionWS),ddx(positionWS)))。
//以上记录作为扩展知识，与本例无关。
//该例子为 Gouraud着色
Shader "Lakehani/URP/Lighting/Gouraud"
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
                half4 finalColor : TEXCOORD1;
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

                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                half smoothness = exp2(10 * _Smoothness + 1);
                half3 normalWS = normalize(TransformObjectToWorldNormal(IN.normalOS));
                half3 viewWS =  SafeNormalize(GetWorldSpaceViewDir(positionWS));


                half3 specularColor = LightingSpecular(lightColor, light.direction, normalWS, viewWS, _SpecularColor, smoothness);
                half3 diffuseColor = LightingLambert(lightColor,light.direction,normalWS) * _BaseColor;
                half3 ambientColor = unity_AmbientSky.rgb * _BaseColor;

                OUT.finalColor = half4(diffuseColor + specularColor + ambientColor,1);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return IN.finalColor;
            }

            ENDHLSL
        }
    }
}
