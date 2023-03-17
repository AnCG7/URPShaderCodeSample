//本村线
//衣服缝隙和肌肉接缝的黑色线条，伤疤等，直接绘制在贴图上，镜头拉近后会失真，如果使用非常高分辨率的贴图，会出现占用过多性能或者平台不支持的问题
//需要一种有效的方法
//本村线的本质是使UV对齐横向或纵向排列纹素采样。图像放大到最大都是方格子（像素），横平竖直的边缘是完全填充的状态（可以在photoshop里面画条水平线或者垂直线和画条斜线，放大观察边缘的变化）
//增加面数，拆模型的UV和重布线来对齐横向或者纵向的纹素，这同样也是缺点，复杂的制作流程和增加了更多的面数
//场景中的示例是我尝试制作的（布线不太好看），一开始只想做个简单的，但是我觉得体现不出来本村线的优点和缺点
//所以我就做了个稍微复杂一点的图案，拆面改uv和布线搞得我头大，如果对于复杂的模型这样子搞得是多么复杂的过程啊！
//打开纹理的双线性插值（Bilinear）可以使过渡更加柔达到抗锯齿的效果，可以切换纹理的Filter Mode为Point或者Bilinear观察边缘变化
//该文件的主要目的是记录本村线的知识和参考资料，其他代码和普通的仅显示Texture的shader一模一样，因为本村线是通过增加顶点修改UV和布线调整采样的，所以不需要对shader做任何修改
//我将Blender源文件放到了项目根目录（和Assets文件夹同级）的ArtSrc文件夹中，也可以自己在blender调整一下看看

//参考资料
//原文（罪恶装备）与其说是讲本村线，更是在讲他们的一整套卡渲作业流程
//https://www.4gamer.net/games/216/G021678/20140703095/index_2.html
//https://www.youtube.com/watch?v=yhGjCzxJV3E&t=7s     24：18
//对原文的总结
//https://www.jianshu.com/p/017465419da5
//一些描边方案
//https://zhuanlan.zhihu.com/p/446479066
//双线性插值
//https://www.bilibili.com/video/BV1X7411F744?p=9&vd_source=eb61a060e99be0bb1053c402ee691117   25：46

Shader "Lakehani/URP/NPR/Cartoon/Inner Line BenCunXian"
{
    Properties
    {
       _BaseColor("BaseColor", Color) = (1,1,1,1)
       _BaseMap("BaseMap", 2D) = "white" {}
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

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
            }
            ENDHLSL
        }
    }
}
