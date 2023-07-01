//在高光周围加扩散色，起到衬托的作用
//本质是画2次高光，但是范围不一样，然后叠在一起


//参考资料 
//https://zhuanlan.zhihu.com/p/575096572 搜索 高光周围加色

Shader "Lakehani/URP/NPR/Cartoon/Stylized Highlight Spread"
{

    Properties
    {
        //关于属性的默认特性Header、枚举、Space等参考 https://docs.unity3d.com/ScriptReference/MaterialPropertyDrawer.html
        _BaseColor("Base Color",Color) = (0,0,0,1)

        [Space(10)]
        _SpecularScale ("Specular Scale", Range(0,1)) = 0.01
        _SpecularSmooth ("Specular Smooth", Range(0,1)) = 0.001
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)

        [Space(10)]
       	_SpreadSmooth ("Spread Smooth", Range(0, 1)) = 0.3
        _SpreadColor ("Spread Color", Color) = (1,0,0,1)
        _SpreadScale ("Spread Scale", Range(0,1)) = 0.3

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
                float4 tangentOS     : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 viewWS : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _BaseColor;
            half _SpecularScale;
            half _SpecularSmooth;
            half4 _SpecularColor;
            half _SpreadSmooth;
            half4 _SpreadColor;
            half _SpreadScale;
            CBUFFER_END

            half StylizedHighlightScale(half3 lightDirWS,half3 normalWS,half3 viewWS,half highlightScale)
            {
                half3 halfDirWS = normalize(viewWS + lightDirWS);
                half NdotH = saturate(dot(normalWS, halfDirWS));
                //这里是常规的高光使用的方式，当然可以把【B】注释了，用下面这2行
                //half smoothness = exp2(10 * highlightScale + 1);
                //half modifier = pow(NdotH, smoothness);
                //【B】反正后面计算颜色用的是smoothstep函数，所以我想简单一点直接乘上一个数
                half modifier = NdotH * (highlightScale + 0.5);
                return modifier;
            }

            half3 StylizedHighlightSmoothLerp(half3 startColor, half3 endColor, half smooth,half lerpDelta)
            {
                half colorLerpDelta = smoothstep(0.5 - smooth * 0.5,0.5 + smooth * 0.5,lerpDelta);
                half3 finialColor = lerp(startColor,endColor,colorLerpDelta);
                return finialColor;
            }

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
                //获取灯光数据
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;

                //我这里是为了方便阅读，所以放到了2个函数里面，可以把这些函数拆了都写到一起，其实就是计算了2遍高光
                //先计算扩散的大圈的高光A，然后把A和基础色插值，得到结果B，
                //再计算小圈的正常的高光，然后和B再插值，得到最终结果

                //将扩散的高光和基础颜色插值在一起
                half spreadDelta = StylizedHighlightScale(light.direction,normalize(IN.normalWS), SafeNormalize(IN.viewWS),_SpreadScale);
                half3 spreadColor = StylizedHighlightSmoothLerp(_BaseColor.rgb,_SpreadColor.rgb * lightColor,_SpreadSmooth,spreadDelta);

                //将正常的高光和上一步的结果插值在一起
                half specularDelta = StylizedHighlightScale(light.direction,normalize(IN.normalWS), SafeNormalize(IN.viewWS),_SpecularScale);
                half3 finalSpecularColor = StylizedHighlightSmoothLerp(spreadColor.rgb,_SpecularColor.rgb * lightColor,_SpecularSmooth,specularDelta);

                half4 totalColor = half4(finalSpecularColor.rgb,1);
                return totalColor;
            }

            ENDHLSL
        }
    }
}
