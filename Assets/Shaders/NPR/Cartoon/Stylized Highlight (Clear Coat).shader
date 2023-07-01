//一个关于卡渲染高光的油漆光的做法
//把经典光照模型中的N·H，改成N·V，这个高光形状就会非常接近于卡通的清漆光的形状
//很适合用来处理一些皮革，圆柱形的金属等

//参考资料：
//https://developer.unity.cn/projects/618ce1e7edbc2a05bb615020
//搜素 清漆光

Shader "Lakehani/URP/NPR/Cartoon/Stylized Highlight Clear Coat"
{
    Properties
    {
        _SpecularColor ("SpecularGloss", Color) = (1,1,1,1)
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

            //修改自"Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"的LightingSpecular函数
            half LightingClearcoatSpecularModifier(half3 lightDir, half3 normal, half3 viewDir, half smoothness)
            {
                //float3 halfVec = SafeNormalize(float3(lightDir) + float3(viewDir));
                //half NdotH = saturate(dot(normal, halfVec));
                //half modifier = pow(NdotH, smoothness);

                //上面是经典Blinn-Phone高光，但是我们需要的是特殊的清漆光类似的效果，所以将 N·H 改成 N·V 即可
                half NdotV = saturate(dot(normal, viewDir));
                half modifier = pow(NdotV, smoothness);

                return modifier;
            }


            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                half smoothness = exp2(10 * _Smoothness + 1);

                half modifier = LightingClearcoatSpecularModifier(light.direction, normalize(IN.normalWS), SafeNormalize(IN.viewWS), smoothness);

                //half3 specularColor = lightColor * _SpecularColor.rgb * modifier;
                //上面注释的是正常的高光样式，下面的是用smoothstep将高光卡通化，具体参见shader文件 Cel-Shading (Procedural) 中的【标记B】
				half3 specularColor = lerp(half3(0, 0, 0), lightColor * _SpecularColor.rgb, smoothstep(0.5 - modifier * 0.5,0.5 + modifier * 0.5,modifier));


                half4 totalColor = half4(specularColor.rgb,1);
                return totalColor;
            }

            ENDHLSL
        }
    }
}
