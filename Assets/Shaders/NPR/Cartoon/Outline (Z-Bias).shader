//Z-Bias渲染背面而不是渲染正面，然后观察空间下物体的顶点的Z值沿着相机方向移动一点距离，也就是更靠近摄像机，使得边缘凸出
//该方式等于是又将物体画了一遍，所以我们有2个Pass，第1个Pass正常画，第2个Pass是轮廓
//想要2个Pass，简单的办法就是在RendererDeature上加一个LightMode Tags，注意看主摄像机的Renderer是CartoonRenderer
//CartoonRenderer直接从默认的ForwardRenderer复制的，啥也没改，因为我不想影响其他的东西，然后加了个Render Objects并添加了一个叫Outline的LightMode
//所以我下面的第2个Pass叫Outline
//轮廓只画背面，所以需要Cull Front
//其实相当于一个模型渲染了2次；也相当于2个一样的模型，一个只正常渲染，一个只负责描边然后重叠在一起
//当描边过粗时，该效果不好，你会看到多出来一个物体，毕竟只是再画一遍然后偏移

//参考资料：
//https://zhuanlan.zhihu.com/p/129291888
//https://zhuanlan.zhihu.com/p/26409746


Shader "Lakehani/URP/NPR/Cartoon/Outline Z-Bias"
{
    Properties
    {
        _OutlineColor ("Outline Color", Color) = (0,0,0,1)
        _ZBias ("Outline Width (ZBias)",Float) = 0.5
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
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
            };



            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return half4(1,1,1,1);
            }

            ENDHLSL
        }
        Pass
        {
            Tags{"LightMode" = "Outline"}

            Cull Front
            Offset 2,1

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
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _OutlineColor;
            half _ZBias;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                //转换到观察空间
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 positionVS = TransformWorldToView(positionWS);

                //简单的写法,观察空间中，在z轴上移动会产生远近的变化
                //【A】但是当物体的xy不在相机中心附近时，设置较厚的描边会和物体本身在透视上有明显异常，从而让描边看起来像是另一个物体
                //对于Cube这类物体描边不等宽
                positionVS.z += _ZBias;

                ////这里简单改进一下，可以注释上一行代码解开下面全部注释的代码看看
                ////观察空间中摄像机的坐标是原点，如果是正交相机仅需要一个指向相机的向量z的，所以直接返回相机的朝向就好了
                //float3 viewToPosDir = float3(0,0,1);
                ////这里参考ShaderVariablesFunctions.hlsl文件的GetWorldSpaceNormalizeViewDir函数的实现，来区分透视和正交
                ////如果是透视相机，需要特殊处理一下，要不直接移动Z就会有【A】的问题
                //if (IsPerspectiveProjection())
                //{
                //   //这里求点到相机位置的单位向量
                //   viewToPosDir = normalize(float3(0,0,0) - positionVS);
                //}
                ////然后缩放这个向量
                //positionVS +=  viewToPosDir * _ZBias;
                
                OUT.positionHCS = TransformWViewToHClip(positionVS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return _OutlineColor;
            }

            ENDHLSL
        }
    }
}
