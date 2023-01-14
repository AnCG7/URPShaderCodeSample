//基础说明不再赘述看Cel Shading (Ramp).shader文件的开头
//Cel Shading (Ramp)只有漫反射
//这里我把漫反射和菲涅尔绘制在一张Ramp上采样

//photoshop里面绘制
//因为法线和灯光夹角越小越亮，所以映射[0,1]，从左到右越来越亮【图层A】
//因为菲涅尔是是是法线和视角夹角越大越亮，所以映射[0,1],从上到下越来越亮【图层B】
//然后用 线性减淡（添加）也就是加法的图层混合模式就好了
//我的示例图片看 Hard (Fresnel)
Shader "Lakehani/URP/NPR/Cartoon/Cel Shading Ramp Fresnel"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _FresnelPow("Fresnel Pow", Range(0,2)) = 1
        [NoScaleOffset] _Ramp ("Ramp",2D)  = "white" {}
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
            half _FresnelPow;
            CBUFFER_END
            TEXTURE2D(_Ramp);SAMPLER(sampler_Ramp);


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

                //【标记A】Lambert漫反射(Half-Lambert也可以)这个是法线和灯光的夹角，夹角越小越亮，并限制到[0,1]的范围
                float NdotL = saturate(dot(normalWS, light.direction));
                //【标记B】这里模拟视角相关的光照分量(菲涅尔效果)，同样的法线和视角越小，值越大并限制在[0,1]
                float NdotV = saturate(dot(normalWS, viewWS) * _FresnelPow);
                //直接在Ramp采样，这个时候Ramp是个2维的，如果只有上面的【标记A】没有【标记B】的话Ramp就可以是一个1维
                //这里使用的图片是我自己画的Hard (Fresnel)
                half4 ramp = SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, float2(NdotL,NdotV));
                half4 totalColor =  ramp * _BaseColor; 

                return totalColor;
            }

            ENDHLSL
        }
    }
}
