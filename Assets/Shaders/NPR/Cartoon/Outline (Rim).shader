//本质上来说这是一个利用模型法线和视角向量的夹角大小来计算描边效果的
//类似与菲涅尔效果
//该效果实现非常简单，优势：一个Pass，计算量小，整体开起来还行；劣势：当曲率变化在物体的边缘处并不均一时，描边的粗细无法控制；对于较为平整的面来说，描边会失效的状态


//参考资料：
//https://alexanderameye.github.io/notes/rendering-outlines/
//https://zhuanlan.zhihu.com/p/129291888
//https://zhuanlan.zhihu.com/p/26409746


Shader "Lakehani/URP/NPR/Cartoon/Outline Rim"
{
    Properties
    {
        _OutlineColor ("Outline Color", Color) = (0,0,0,1)
        _OutlineWidth ("Outline Width",Range(0,1)) = 0.5
        _OutlineSmoothness("Outline Smoothness",Range(0,1)) = 0.5
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
            half4 _OutlineColor;
            half _OutlineWidth;
            half _OutlineSmoothness;
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

                float NdotV = saturate(dot(normalWS, viewWS));

                //不管怎么玩，核心都在NdotV上，也就是法线和视角的夹角上
                //直接利用NdotV和宽度比较
                //【A】half outline = NdotV < _OutlineWidth ? NdotV/4  : 1;

                //这种写法就是菲涅尔了
                //【B】half outline = pow(max(NdotV,0.001),_OutlineWidth);

                //【C】不加工直接就用NdotV当uv去映射Ramp也一点问题都没有
                
                //我这里用smoothstep演示方便一些
                //step函数的作用仅仅是我想在_OutlineWidth为0时让_OutlineSmoothness失效；NdotV + 0.001是想_OutlineWidth为0时轮廓完全消失；
                //很显然这里可以也可以用一个Ramp纹理类似【C】而不是用smoothstep函数，实际上如果真的用这方式来描边，一般也是用Ramp纹理来查询，这里我只是演示一下
			    half4 outlineRamp = smoothstep(_OutlineWidth, _OutlineWidth + _OutlineSmoothness * step(0.001,_OutlineWidth), NdotV + 0.001) + _OutlineColor;
                //仅仅显示描边，所以漫反射固定为白色
                half4 totalColor = half4(1,1,1,1) * outlineRamp;
                return totalColor;
            }

            ENDHLSL
        }
    }
}
