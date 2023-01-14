//NPR （Non-photorealistic rendering）非真实感渲染，范围很大，卡通只是其中一种，其他的例如素描
//相对的 真实感渲染Photorealistic rendering
//Tone Based Shading 基于色调着色，特点在冷色调和暖色调之间插值
//因为色阶变化一点，其实就会很明显的体现出来，而主要风格由美术决定，所以最好的办法就是用Ramp纹理或者说是一个查询表
//我们把原先Phong或者Blinn-Phong着色中的漫反射和高光，重新在Ramp纹理上采样，Ramp是一个降梯度后的图片，使用起来比较灵活
//参考文章
//https://users.cs.northwestern.edu/~ago820/thesis/node26.html
//https://zhuanlan.zhihu.com/p/110025903


//渲染过程分为着色、外描边、边缘光、高光，这里我只先列举着色部分



Shader "Lakehani/URP/NPR/Cartoon/Tone Based Shading"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _WarmColor ("Warm Color", Color) = (1,1,1,1)
        _CoolColor ("Cool Color", Color) = (1,1,1,1)
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
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
            half4 _WarmColor;
            half4 _CoolColor;
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
                half3 normalWS = normalize(IN.normalWS);
                half3 viewWS =  SafeNormalize(IN.viewWS);
                half smoothness = exp2(10 * _Smoothness + 1);

                //这里灯光方向反过来方便后面带入公式
                half NdotL = dot(normalWS, -light.direction);
                float3 halfVec = SafeNormalize(float3(light.direction) + float3(viewWS));
                half NdotH = saturate(dot(normalWS, halfVec));

                //https://users.cs.northwestern.edu/~ago820/thesis/node26.html
                half coolAlpha = _CoolColor.a;
                half warmBeta = _WarmColor.a;
                //kd为黑色到自身颜色的渐变，既漫反射的颜色
                half3 kd = _BaseColor * ( 1 - NdotL) + half3(0,0,0) * NdotL;
                //根据参考文档kBlue对应的是冷色调，kYellow对应的是暖色调 kBlue = (0,0,b) kYellow =(y,y,0)
                //我这里直接用2个color表示了，kBlue = _CoolColor.rgb, kYellow = _WarmColor.rgb;
                //可以看到这个公式等于将一个冷色调到暖色调的ramp和一个物体背光面到向光面颜色的Ramp相加的结果(Ramp)
                half3 kCool = _CoolColor.rgb + coolAlpha * kd;
                half3 kWarm = _WarmColor.rgb + warmBeta * kd;
                half3 diffuseColor = ((1 + NdotL) / 2) * kCool + (1 - (1 + NdotL) / 2) * kWarm;
                //常规的Blinn-Phone高光
                half3 specularColor = LightingSpecular(lightColor, light.direction, normalWS,viewWS, _SpecularColor, smoothness);
                //常规的环境光
                half3 ambientColor = unity_AmbientSky.rgb * _BaseColor;
                half4 totalColor = half4(diffuseColor + specularColor + ambientColor ,1);

                return totalColor;
            }

            ENDHLSL
        }
    }
}
