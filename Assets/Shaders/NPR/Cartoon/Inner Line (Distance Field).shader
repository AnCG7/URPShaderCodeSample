//距离场又是个高大上的名词
//无符号距离场或者有符号距离场(SDF)是指建立一个空间场，这个空间场中每个像素或体素记录自己与周围像素或体素的距离
//拿2D的距离场举例
//无符号距离场，例如我有一个矩形，矩形内部是0，矩形外部距离矩形边缘越远数值越大
//有符号距离场即SDF，例如我有一个矩形，矩形的边是0，矩形的内部为负数，距离内边缘越远数值越小；矩形边外部是正数，距离矩形外边缘越远数值越大
//还是不理解的话看下面参考资料的【A】一目了然
//距离场的图像，应作为数据使用，所以要在Unity里关闭对该图像的压缩，shader中通过采样获得距离数据
//但是需要通过if或者step来判断而不是直接作为颜色返回出去
//我这里为了可以调整边缘的柔和程度，所以用了smoothstep函数来做，重点代码就1行，实现也很简单
//缺点是如果DF贴图分辨率过低，即数据损失，也会出现锯齿；尖锐的顶点的尖角会缺失，这个问题在下面参考资料的【B】的pdf文档的最后给出了解决方法
//DF的贴图需要占用一个通道，但是好在DF的贴图可以很小
//DF同样也可以制作文字，描边，阴影，融合，画线等等，DF和SDF可以说应用广泛，这里只是用来展示拉近后抗锯齿的效果。下面参考资料的【C】给出了一些扩展资料
//实际项目需要根据实际情况选择合适的算法生成DF或SDF贴图
//示例使用的DF贴图使用Unity Asset Store 免费插件生成 https://assetstore.unity.com/packages/tools/utilities/sdf-toolkit-free-50191
//其实在photoshop里面给图形加外发光作为DF；给边框加外发光和内发光作为sdf，也可以尝试使用。

//参考资料
//距离场的解释 【A】
//https://shaderfun.com/2018/03/23/signed-distance-fields-part-1-unsigned-distance-fields/
//https://shaderfun.com/2018/03/25/signed-distance-fields-part-2-solid-geometry/
//经典文档 利用距离场超近距离无锯齿 【B】
//https://steamcdn-a.akamaihd.net/apps/valve/2007/SIGGRAPH2007_AlphaTestedMagnification.pdf
//SDF扩展资料
//https://www.iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
//https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm 
//https://www.shadertoy.com/view/4tByz3 
//https://www.ronja-tutorials.com/post/035-2d-sdf-combination/ 

Shader "Lakehani/URP/NPR/Cartoon/Inner Line Distance Field"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _MarkColor("Mark Color", Color) = (0,0,0,1)
        _DFMap("DF Map", 2D) = "white" {}
        _SmoothnessMin("Smoothness Min",Float) = 0.2 //不能大于_SmoothnessMax，这2个参数直接用在了smoothstep函数里面
        _SmoothnessMax("Smoothness Max",Float) = 0.2
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

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 positionHCS  : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _DFMap_ST;
            half4 _BaseColor;
            half4 _MarkColor;
            float _SmoothnessMin;
            float _SmoothnessMax;
            CBUFFER_END

            TEXTURE2D(_DFMap);
            SAMPLER(sampler_DFMap);

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _DFMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //采样获得距离
                half distance = SAMPLE_TEXTURE2D(_DFMap, sampler_DFMap, IN.uv).r;
                //就这一句，调节smoothstep的值
                half t = smoothstep(_SmoothnessMin, _SmoothnessMax, distance);
                half4 finalColor = lerp(_BaseColor,_MarkColor,t);
                return finalColor;
            }
            ENDHLSL
        }
    }
}
