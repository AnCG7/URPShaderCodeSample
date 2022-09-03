//基础说明不再赘述看Cel Shading (Ramp).shader文件的开头
//Cel Shading (Ramp)只有漫反射的Ramp，但是没有高光
//这里我加了高光的Ramp，道理和漫反射的Ramp一样
//当然可以把高光和漫反射画到一张Ramp上
//例如Ramp的UV[0,x]表示漫反射，[1,x]表示高光

Shader "Lakehani/URP/UPR/Cartoon/Cel Shading Ramp Specular"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        [NoScaleOffset] _DiffuseRamp ("Diffuse Ramp",2D)  = "white" {}
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
        [NoScaleOffset] _SpecularRamp ("Specular Ramp",2D)  = "white" {}
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
            half3 _SpecularColor;
            half _Smoothness;
            CBUFFER_END
            TEXTURE2D(_DiffuseRamp);SAMPLER(sampler_DiffuseRamp);
            TEXTURE2D(_SpecularRamp);SAMPLER(sampler_SpecularRamp);
            


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
                //Lambert漫反射(Half-Lambert也可以，没什么固定的就是个公式)这个是法线和灯光的夹角，夹角越小越亮，并限制到[0,1]的范围
                float NdotL = saturate(dot(normalWS, light.direction)); 
                //用这个[0,1]的范围采样，所以Ramp纹理最左边是最黑的地方也就是背光面，最右边是最亮的地方，也就是向光面
                half4 diffuseRamp = SAMPLE_TEXTURE2D(_DiffuseRamp, sampler_DiffuseRamp, float2(NdotL,NdotL));
                half3 diffuseColor = diffuseRamp.rgb * _BaseColor;

                //Lighting.hlsl的LightingSpecular函数拆开了，因为需要采样高光的ramp
                float3 halfVec = SafeNormalize(float3(light.direction) + float3(viewWS));
                half NdotH = saturate(dot(normalWS, halfVec));
                half modifier = pow(NdotH, smoothness);
                half4 specularRamp = SAMPLE_TEXTURE2D(_SpecularRamp, sampler_SpecularRamp, float2(modifier,modifier));
                half3 specularColor = _SpecularColor.rgb * specularRamp.rgb * lightColor;
                //高光在背面也可能被看到，因为我们用diffuse已经被我们重新ramp了范围，所以可以自己规定一个高光的范围
                //如果diffuseColor的Ramp是从黑色到白色，可以直接specularColor乘diffuseRamp就行了
                //我演示用的_DiffuseRamp是灰色到白色,目的是直接上色方便演示，所以我把高光的范围画在了Hard (Alpha spacular range)的Ramp纹理的A通道
                //关于photoshop PNG的alpha通道存储结果不正确的问题讨论 https://forum.unity.com/threads/how-to-save-a-png-from-photoshop-with-alpha-channel.436317/
                //使用photoshop的SuperPNG插件来正确存储Alpha通道到PNG http://www.fnordware.com/superpng/ 或者 另存为TGA格式
                //当然可以什么都不处理，用单独的AO贴图来控制也行，这个没有固定的玩法
                specularColor *= diffuseRamp.a;
                //常规的环境光
                half3 ambientColor = unity_AmbientSky.rgb * _BaseColor;

                half4 totalColor = half4(diffuseColor + specularColor + ambientColor,1); 

                return totalColor;
            }

            ENDHLSL
        }
    }
}
