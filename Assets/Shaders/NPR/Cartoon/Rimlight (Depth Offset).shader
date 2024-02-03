//使用屏幕空间深度偏移的方式来实现边缘光的方式
//一般来说我们使用菲涅尔效果来实现边缘光，但是菲涅尔有个问题因为计算和模型的法线以及视角有关系，所以边缘的宽度差距较大
//对于面数较少或者法线方向较为一致的对象或者说硬表面（例如：Cube），菲涅尔效果不佳
//需要一种更扁平，能够突出轮廓的边缘光
//深度偏移边缘光，既得到当前的深度A，沿观察空间下的法线方向偏移一定距离得到深度B，然后B-A再使用类似step方式得到边缘范围

//表面看起来和外描边很像，但是更类似与内描边的感觉

//深度缓冲和深度图不是一个东西，我们采样需要在深度图上，这个深度图Unity为我们构建出来的一张单独的图
//记得打开Universal Render Pipeline Asset 上的 Depth Texture 选项
//记得实现DepthOnly Pass，该Pass将物体写入到深度图中供我们采样，不知道DepthOnly该怎么写，可以直接参考URP自带的默认的那几个Shader

//放一个角色模型效果更加明显，为不增加工程大小，所以我就不放了

//参考资料：
//https://www.gdcvault.com/play/1024126/Huddle-up-Making-the-SPOILER 44:42
//https://zhuanlan.zhihu.com/p/476051447
//https://zhuanlan.zhihu.com/p/551629982
//https://zhuanlan.zhihu.com/p/365339160

//其他资料：
//https://zhuanlan.zhihu.com/p/505030222

Shader "Lakehani/URP/NPR/Cartoon/Rimlight Depth Offset"
{
    Properties
    {
        _RimColor ("Rim Color", Color) = (1,1,1,1)
        _RimOffset ("Rim Offset", Float) = 1
        _Threshold ("Threshold", Float) = 1
        _FresnelPow("Fresnel Pow",Range(0,10)) = 1
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS      : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float4 positionNDC  : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 positionVS  : TEXCOORD2;
                float3 normalVS : TEXCOORD3;
                float3 normalWS : TEXCOORD4;
                float3 viewWS : TEXCOORD5;

            };
            CBUFFER_START(UnityPerMaterial)
            half4 _RimColor;
            half _RimOffset;
            half _Threshold;
            half _FresnelPow;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
				OUT.positionNDC = vertexInput.positionNDC;
                OUT.positionWS = vertexInput.positionWS;
                OUT.positionVS = vertexInput.positionVS;
                OUT.positionHCS = vertexInput.positionCS;
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.normalVS = mul(OUT.normalWS, (float3x3) UNITY_MATRIX_I_V); 
                OUT.viewWS = GetWorldSpaceViewDir(OUT.positionWS);

                return OUT;
            }

            //Linear01Depth作为参考
            half Linear01DepthOffsetRim(float2 screenUV,float2 screenOffsetUV,half threshold)
            {
                //采样当前得深度
                float screenDepth = SampleSceneDepth(screenUV);
                //转到线性空间范围为[0,1] 0为相机得位置，1为远裁剪平面（far）得位置
                float screenLinearDepth = Linear01Depth(screenDepth, _ZBufferParams);
                //采样偏移后得
                float offsetDepth = SampleSceneDepth(screenOffsetUV);
                //转到线性空间范围为[0,1] 0为相机得位置，1为远裁剪平面（far）得位置
                float offsetLinearDepth = Linear01Depth(offsetDepth, _ZBufferParams);
                //深度差
                float diff = offsetLinearDepth - screenLinearDepth;    
                //限制一个范围,因为Linear01Depth函数是[0,1]所以差值很小，得缩小一下threshold
                float rim = step(threshold * 0.0001,  diff);
                return rim;
            }

            half LinearEyeDepthOffsetRim(float2 screenUV,float viewSpaceDepath,float2 screenOffsetUV,half threshold)
            {
                //采样当前得深度
                //float screenDepth = SampleSceneDepth(screenUV);
                //转到View Space
                //float screenViewDepth = LinearEyeDepth(screenDepth, _ZBufferParams);

                //上面注释的写法是采样一次当前得深度和Linear01DepthOffsetRim得做法一模一样
                //viewSpaceDepath是相机空间下得z坐标，这个值可以直接拿到，就是IN.positionHCS.w，所以我不需要再采样一次
                float  screenViewDepth = viewSpaceDepath;

                //采样偏移后得深度
                float offsetDepth = SampleSceneDepth(screenOffsetUV);
                //转到线性空间处于ViewSpace，就是再相机空间下的z坐标
                float offsetScreenViewDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);
                //都是相同空间下的正常的坐标值直接减
                float diff = saturate(offsetScreenViewDepth - screenViewDepth);
                //限制一个范围，缩小一下threshold，方便小幅度调整
                float rim = step(threshold * 0.1, diff);
                return rim;
            }
            
            half4 frag(Varyings IN) : SV_Target
            {

                float3 normalVS = normalize(IN.normalVS);
                //screen pos 
                //注意理解CS到屏幕空间转换时在Unity中坐标xyzw的范围，要不怎么算都不对，https://zhuanlan.zhihu.com/p/505030222

                //也有是类似这样的做法，此做法为使用NDC或者ComputeScreenPos出现xy/w，这里补充一下，因为顶点着色器中计算时并没有真的/w，只有/w才完成透视除法
                //float2 screenUV = IN.positionNDC.xy / IN.positionNDC.w;

                //SV_POSITION修饰的IN.positionHCS通过顶点着色器传递到像素着色器后，xy为屏幕坐标，zw和裁剪空间下一样，z[-w,w]，w[Near,Far]参考ComputeScreenPos函数
                float2 screenPos = IN.positionHCS.xy;
                //除以屏幕宽高，将屏幕坐标转到[0,1]用于采样
                float2 screenUV = float2(screenPos.x / _ScreenParams.x, screenPos.y / _ScreenParams.y);
                //将ViewSpace下的法线取xy，因为在屏幕空间偏移，所以在xy的方向上偏移一个值
                float2 screenOffsetUV = screenUV + normalVS.xy * _RimOffset * 0.001;

                //使用Linear01Depth来偏移
                //float rim = Linear01DepthOffsetDiff(screenUV,screenOffsetUV,_Threshold);

                //使用LinearEyeDepth来偏移，原理和上面一样没啥区别，函数在上面，看一看详细注释
                //因为Linear01Depth和LinearEyeDepth这2个函数得结果取值范围不一样，所以注意参数调节否则会出现怎么写，效果都不对
                //注意理解NDC到屏幕空间时在Unity中坐标xyzw的范围，要不怎么算都不对，https://zhuanlan.zhihu.com/p/505030222
                float rim = LinearEyeDepthOffsetRim(screenUV,IN.positionHCS.w,screenOffsetUV,_Threshold);

                //可以结合菲涅尔
                half3 N = normalize(IN.normalWS);
                half3 viewDir = normalize(IN.viewWS);
                half3 V = normalize(viewDir);
                float fresnel = pow(1-saturate(dot(N,V)),_FresnelPow);

                half4 col = lerp(0, rim, fresnel) * _RimColor;
                
                return col;
            }

            ENDHLSL
        }

        Pass
        {
            //参考
            //Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl
            //Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl
            //写入深度图
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

           Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 position     : POSITION;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
            };

            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.position.xyz);
                return output;
            }

            half4 DepthOnlyFragment(Varyings input) : SV_TARGET
            {
               
                return 0;
            }

            ENDHLSL
        }
    }
}
