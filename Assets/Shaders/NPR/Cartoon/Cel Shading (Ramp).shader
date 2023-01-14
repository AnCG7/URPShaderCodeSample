//NPR （Non-photorealistic rendering）非真实感渲染，范围很大，卡通只是其中一种，其他的例如素描
//相对的 真实感渲染Photorealistic rendering
//Cel Shading 又称赛璐珞渲染，是一种（NPR），一种日式卡通风格，特点减少色阶
//因为色阶变化一点，其实就会很明显的体现出来，而主要风格由美术决定，所以最好的办法就是用Ramp纹理或者说是一个查询表
//我们把原先Phong或者Blinn-Phong着色中的漫反射和高光，重新在Ramp纹理上采样，Ramp是一个降梯度后的图片，使用起来比较灵活
//参考文章 https://zhuanlan.zhihu.com/p/110025903

//渲染过程分为着色、外描边、边缘光、高光，这里我只先列举着色部分
//注意我提供的常见的几个Ramp纹理Hard、Soft、3level，都是我为了适配Lambert漫反射的映射画出来的，记得把图片的Wrap Mode改为Clamp否则采样到边缘的时候会有误差

Shader "Lakehani/URP/NPR/Cartoon/Cel Shading Ramp"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
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

                //Lambert漫反射(Half-Lambert也可以，没什么固定的就是个公式)这个是法线和灯光的夹角，夹角越小越亮，并限制到[0,1]的范围
                float NdotL = saturate(dot(normalWS, light.direction));
                //用这个[0,1]的范围采样，所以Ramp纹理最左边是最黑的地方也就是背光面，最右边是最亮的地方，也就是向光面
                half4 ramp = SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, float2(NdotL,NdotL));
                half4 totalColor =  ramp * _BaseColor; 

                return totalColor;
            }

            ENDHLSL
        }
    }
}
