/*
这个东西难点不在shader，如何绘制为几个阴影的关键帧【2】,根据关键帧我们可以生成每个关键帧的SDF图，再将SDF融合成一个完整的sdf图
测试图片是我自己绘制的，导出UV布局图然后再PS中绘制，我不是美术，所以绘制的不好，作为参考问题不大
绘制后的关键帧使用【1】中的工具可以直接生成最终的一张SDF图，我们直接使用就好了。DCC软件也有很多其他的快速生成这是面部阴影的SDF的插件或者控件

参考资料：
【1】https://github.com/xudxud/Unity-SDF-Generator
https://zhuanlan.zhihu.com/p/411188212
https://zhuanlan.zhihu.com/p/26217154
【2】https://github.com/EricHu33/AnimeShadingPlus-Anime-Toon-Shader/blob/main/Anime%20Shading%20Plus(+)%20User%20Manual%20e9875988ae1e41caa5198370d9cc963d/Face%20Shadow%20Map-%20Creation%20&%20Baking%20Workflow%20d3b8769021e04683a2f2ae4cf16ac810.md
*/

Shader "Lakehani/URP/NPR/Cartoon/Face Shadow SDF"
{
    Properties
    {
        _SDFMap("SDF Texture", 2D) = "white" {}
        _ThresholdMinOffset("Threshold Min Offset",Float) = 1
        _ThresholdMaxOffset("Threshold Max Offset",Float) = 1
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
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 forwardDirWS : TEXCOORD1;
                float3 rightDirWS : TEXCOORD2;
            };

            CBUFFER_START(UnityPerMaterial)
            half _ThresholdMinOffset;
            half _ThresholdMaxOffset;
            CBUFFER_END
            TEXTURE2D(_SDFMap);SAMPLER(sampler_SDFMap);

  

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                OUT.forwardDirWS = TransformObjectToWorldDir(half3(0,0,1));
                OUT.rightDirWS = TransformObjectToWorldDir(half3(1,0,0));
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                float3 lightDirWS = normalize(light.direction);
                float3 foward = normalize(IN.forwardDirWS);
                float3 right = normalize(IN.rightDirWS);

                // 计算前向向量与光的点积
                half LDotF = dot(lightDirWS,foward);
                // 计算右向向量与光的点积
                half LDotR = dot(lightDirWS,right);
                
                // 根据右向点积结果决定使用 uv.x 还是 1 - uv.x
                float f = lerp(IN.uv.x,1-IN.uv.x,step(0,LDotR));

                half sdfValue = SAMPLE_TEXTURE2D(_SDFMap, sampler_SDFMap,float2(f,IN.uv.y)).r;
                // 当 180 度时，即光照从后方照来时，颜色应该是全黑的，此时 dot(lightDir,headForward) 为 -1
                // 对应映射为 1，此时 SDF 图中所有点的值都小于 1，颜色全黑，符合预期
                // 当 90 度时，颜色应该是半透明的，此时 dot(lightDir,headForward) 为 0
                // 对应映射为 0.5，SDF 图只有一半的点值大于 0.5，符合预期
                // 当 0 度时，即光照从前方照来时，颜色应该是全白的，此时 dot(lightDir,headForward) 为 1
                // 对应映射为 0，SDF 图中所有点的值都大于 0，颜色全白，符合预期
                float sdfThreshold = 1 - (LDotF * 0.5 + 0.5);
                // 根据阈值调整阴影大小，实现平滑过渡
                half minOffset = max(_ThresholdMinOffset * 0.001,0);
                half maxOffset = max(_ThresholdMaxOffset * 0.001,0);
                float sdfrr = smoothstep(sdfThreshold - minOffset,sdfThreshold + maxOffset,sdfValue);

                half4 totlaColor = half4(sdfrr,sdfrr,sdfrr,1);
                return totlaColor;
            }

            ENDHLSL
        }
    }
}
