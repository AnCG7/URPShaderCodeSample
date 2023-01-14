//卷积这玩意就是取周围的数值然后来个加权平均值
//各类算子Sobel,Roberts,Prewitt,Krisch,罗盘,Laplacian,Canny,Marr-Hildreth(LoG)(DOG) 等
//这里只算深度和法线，当然也可以把颜色、深度、法线都算在里面,同样为了方便对比我这里依然使用Soble算子来计算
//由于后处理会给所有物体都加上效果，为了方便放在一起展示，我新建了Camera Edge Detection Depth Normal摄像机，其Renderer修改为EdgeDetectionDepthNormal
//EdgeDetectionDepthNormal这个是从ForwardRenderer直接复制的，并加上了EdgeDetectionDepthNormalPPFeature
//记得打开Universal Render Pipeline Asset的Depth Texture选项和EdgeDetectionDepthNormalPPFeature的Enable Normal Texture选项

//参考Renderer Feature 如何屏幕后处理
//https://github.com/Unity-Technologies/UniversalRenderingExamples

//要想使用深度和法线信息，需要shader实现DepthNormals的Pass具体文档如下：
//https://docs.unity3d.com/cn/Packages/com.unity.render-pipelines.universal@12.1/manual/upgrade-guide-10-0-x.html?q=DepthNormals

//参考资料：
//https://zhuanlan.zhihu.com/p/357515658
//https://alexanderameye.github.io/notes/edge-detection-outlines/
//https://github.com/jean-moreno/EdgeDetect-PostProcessingUnity
//https://zhuanlan.zhihu.com/p/575272215



Shader "Lakehani/URP/NPR/PostProcessing/Edge Detection DepthNormal"
{
    Properties
    {
        [HideInInspector]_MainTex ("Base (RGB)", 2D) = "white" {}
        _EdgeColor("Edge Color",Color) = (0,0,0,1)
        _SampleDistance("Sample Distance",Float) = 1.0
        _DepthSensitivity("Depth Sensitivity",Float) = 1.0
        _NormalSensitivity("Normal Sensitivity",Float) = 1.0
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
            half _DepthSensitivity;
            half _NormalSensitivity;
            CBUFFER_END
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraNormalsTexture); SAMPLER(sampler_CameraNormalsTexture);
            
            
           
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
                float depthSobelX = 0;
                float depthSobelY = 0;

                float2 normalSobelX = 0;
                float2 normalSobelY = 0;

                //采样周围9个点
                [unroll] for (int i = 0; i < 9; i++)
                {
                    //Linear01Depth 把深度转到[0,1]的线性范围，当然有些时候不转也可以，深度缓冲非线性问题参考 https://zhuanlan.zhihu.com/p/66175070
                    //我这里只是直接SAMPLE_DEPTH_TEXTURE采样，为了方便参考而抛弃了封装，也可以用Unity封装好的函数DeclareDepthTexture.hlsl的SampleSceneDepth函数来采样
                    float2 sampleUV = uv + _MainTex_TexelSize.xy * GSobelSamplePoints[i] * _SampleDistance;
                    float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture,sampleUV),_ZBufferParams);
                    
                    //我这里只是直接SAMPLE_TEXTURE2D采样，为了方便参考而抛弃了封装，也可以用Unity封装好的函数DeclareNormalsTexture.hlsl的SampleSceneNormals函数来采样
                    //float3 normal = UnpackNormalOctRectEncode(SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, sampleUV).xy) * float3(1.0, 1.0, -1.0);

                    float2 normal = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, sampleUV).xy;

                    depthSobelX += depth * GSobelXKernel[i];
                    depthSobelY += depth * GSobelYKernel[i];

                    normalSobelX += normal * GSobelXKernel[i];
                    normalSobelY += normal * GSobelYKernel[i];

                }
                //不想开根号也可以这么做
                //float edge = abs(sobelX) + abs(sobelY);
                float depthEdge = sqrt(depthSobelX * depthSobelX + depthSobelY * depthSobelY);
                //对于超过1维的数据用自己的点乘类比平方
                float normalEdge = sqrt(dot(normalSobelX,normalSobelX) + dot(normalSobelY,normalSobelY));

                depthEdge = depthEdge > _DepthSensitivity ? 1.0 : 0.0;
                normalEdge = normalEdge > _NormalSensitivity ? 1.0 : 0.0;

                //edge越大越可能是边缘
                return max(depthEdge,normalEdge);
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
                float edge = 1 - saturate(Soble(IN.uv));
                half4 mainColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                half4 totalColor = lerp(_EdgeColor,mainColor,edge);
                return totalColor;
            }
            ENDHLSL
        }
        
    }
}
