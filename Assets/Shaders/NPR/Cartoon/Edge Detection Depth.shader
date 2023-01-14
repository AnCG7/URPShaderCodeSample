//卷积这玩意就是取周围的数值然后来个加权平均值
//各类算子Sobel,Roberts,Prewitt,Krisch,罗盘,Laplacian,Canny,Marr-Hildreth(LoG)(DOG) 等
//这里实现一下常用的Sobel算子，来后处理屏幕颜色
//由于后处理会给所有物体都加上效果，为了方便放在一起展示，我新建了Camera Edge Detection Depth摄像机，其Renderer修改为EdgeDetectionDepth
//EdgeDetectionDepth这个Renderer是从ForwardRenderer直接复制的，并加上了EdgeDetectionDepthPPFeature
//记得打开Universal Render Pipeline Asset的Depth Texture选项

//参考Renderer Feature 如何屏幕后处理
//https://github.com/Unity-Technologies/UniversalRenderingExamples

//参考资料：
//https://zhuanlan.zhihu.com/p/357515658
//https://alexanderameye.github.io/notes/edge-detection-outlines/
//https://github.com/jean-moreno/EdgeDetect-PostProcessingUnity



Shader "Lakehani/URP/NPR/PostProcessing/Edge Detection Depth"
{
    Properties
    {
        [HideInInspector]_MainTex ("Main Tex", 2D) = "white" {}
        _EdgeColor("Edge Color",Color) = (0,0,0,1)
        _SampleDistance("Sample Distance",Float) = 1.0
        _EdgeExponent("Edge Exponent",Float) = 50
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline"}

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
            //{TextureName}_TexelSize的文档
            //https://docs.unity3d.com/Manual/SL-PropertiesInPrograms.html
            // a float4 property contains texture size information 
            //x contains 1.0/width | y contains 1.0/height | z contains width | w contains height
            float4 _MainTex_TexelSize;//后面会用到xy来作为采样的偏移，当然换成_CameraDepthTexture_TexelSize也可以
            half4 _EdgeColor;
            half _SampleDistance;
            half _EdgeExponent;
            CBUFFER_END
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
           
            static const float2 GSobelSamplePoints[9] =
            {
                float2(-1, +1), float2(+0, +1), float2(+1, +1),
                float2(-1, +0), float2(+0, +0), float2(+1, +0),
                float2(-1, -1), float2(+0, -1), float2(+1, -1),
            };

            static const half GSobelXKernel[9] =
            {
                +1, +0, -1,
                +2, +0, -2,
                +1, +0, -1,
            };

            static const half GSobelYKernel[9] =
            {
                +1, +2, +1,
                +0, +0, +0,
                -1, -2, -1,
            };

            float Soble(float2 uv)
            {
                float sobelX = 0;
                float sobelY = 0;
    
                //采样周围9个点
                [unroll] for (int i = 0; i < 9; i++)
                {
                    //Linear01Depth 把深度转到[0,1]的线性范围，当然有些时候不转也可以。
                    //深度缓冲非线性问题参考 https://zhuanlan.zhihu.com/p/66175070
                    //https://forum.unity.com/threads/decodedepthnormal-linear01depth-lineareyedepth-explanations.608452/
                    //我这里只是直接SAMPLE_DEPTH_TEXTURE采样，同样也可以参考ShaderGraph生成代码用的SampleSceneDepth
                    float2 sampleUV = uv + _MainTex_TexelSize.xy * GSobelSamplePoints[i] * _SampleDistance;
                    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture,sampleUV);
                    depth = Linear01Depth(depth,_ZBufferParams);

                    sobelX += depth * GSobelXKernel[i];
                    sobelY += depth * GSobelYKernel[i];
                }
    
                float edge = sqrt(sobelX * sobelX + sobelY * sobelY);
                //不想开根号也可以这么做
                //float edge = abs(sobelX) + abs(sobelY);
                //edge越大越可能是边缘，也可以用判断是否大于阈值来取0或1
                return edge;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float edge =  pow(1- saturate(Soble(IN.uv)),_EdgeExponent);
                half4 mainColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                half4 totalColor = lerp(_EdgeColor,mainColor,edge);
                return totalColor;
            }
            ENDHLSL
        }
        
    }
}
