//基础说明不再赘述看Cel Shading (Ramp).shader文件的开头
//程序化就是通过调整参数，然后代码中动态计算参数的结果，其实等于通过计算出来一个Ramp，然后根据漫反射和高光重新在Ramp里面映射得到最后的值
//对于简单的材质来说程序换简单方便，但是对于复杂的情况，并不比直接采样Ramp纹理高明多少
//一般来说因为Ramp纹理采样和调参数各有各的优势，所以其实一般是混在一起用的
//因为实际情况中是以美术效果为准，做法非常多，没有什么像公式一样的通用标准的参数，所以这里我举例了2分色（只有2种颜色过渡）的代码供参考


Shader "Lakehani/URP/NPR/Cartoon/Cel-Shading Procedural"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _BackColor ("Back Color", Color) = (1,1,1,1)
        _BackRange ("Back Range", Range(0,1)) = 0.5
        _DiffuseRampSmoothness ("Diffuse Ramp Smoothness", Range(0,1)) = 0.5
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
        _SpecularRange ("Specular Range", Range(0,1)) = 0.5
        _SpecularRampSmoothness ("Specular Ramp Smoothness", Range(0,1)) = 0.5
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
            half3 _BackColor;
            half _BackRange;
            half _DiffuseRampSmoothness;
            half3 _SpecularColor;
            half _SpecularRange;
            half _SpecularRampSmoothness;
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

                //Half-Lambert漫反射(Lambert也可以，没什么固定的就是个公式)
                half halfLambert = saturate(dot(normalWS, light.direction) * 0.5 + 0.5);

                //【标记A】:smoothstep反走样也可以用【标记B】的办法smoothstep + fwidth，这里也可以用step代替，但是过渡的地方会有锯齿，这里只是演示smoothstep函数的作用，如果用的step函数而产生的锯齿可以在渲染流程最后添加FXAA抗锯齿来解决锯齿
                //所以并不一定说就要用smoothstep来平滑过渡
                half difuseRamp = smoothstep(0,max(_DiffuseRampSmoothness,0.005), halfLambert - _BackRange);

                half3 mainColor =  _BaseColor * lightColor;
                half3 diffuseColor = lerp(_BackColor,mainColor,difuseRamp);
                //同Blinn-Phone高光，因为要对它额外操作，所以不能直接用Lighting.hlsl的LightingSpecular函数
                //如果没必要的话高光部分可以不处理直接用Blinn-Phone高光，艺术效果优先，公式不再是绝对的了
                float3 halfVec = SafeNormalize(float3(light.direction) + float3(viewWS));
                half NdotH = saturate(dot(normalWS, halfVec));

                //【标记B】:利用fwidth + smoothstep来平滑过渡反走样好处是在近距离和远距离观察都很清晰，固定值在近距离观察时会有点糊
                //更多的教程长这个样子，我在《Unity Shader 入门精要》中也找到了这几行代码，写出来作为参考
                //fixed spec = dot(worldNormal, worldHalfDir);
	            //fixed w = fwidth(spec) * 2.0;
	            //fixed3 specular = _Specular.rgb * lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1)) * step(0.0001, _SpecularScale);

                //注意：smoothstep + fwidth反走样，这里可以用step代替，但是过渡的地方会有锯齿，这里只是演示smoothstep函数的作用，如果用的step函数而产生的锯齿可以在渲染流程最后添加FXAA抗锯齿来解决锯齿
                //所以并不一定说就要用smoothstep + fwidth 来平滑过渡

                //如果不使用smoothstep + fwidth也可以用smoothstep的前2个参数也可以是很小的定值，就像上面计算Diffuse的【标记A】
                //我这里我稍微改了一下
                half w = fwidth(NdotH) * 2 + _SpecularRampSmoothness;
                half specularRamp = smoothstep(0,w, NdotH + _SpecularRange - 1);
                
                //防止背面看到高光
                specularRamp *= difuseRamp;

                half3 specularColor = specularRamp * _SpecularColor.rgb * lightColor;

                ////环境光
                half3 ambientColor = unity_AmbientSky.rgb * _BaseColor;

                //混合漫反射+高光+环境光和常规的经验模型没有区别
                half4 totalColor = half4(diffuseColor  + specularColor + ambientColor,1);

                return totalColor;
            }

            ENDHLSL
        }
    }
}
