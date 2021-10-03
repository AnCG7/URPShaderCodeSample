//Matcap全称MaterialCapture（材质捕获）
//MatCap本质是将法线转换到摄像机空间，然后用法线的x和y作为UV，来采样MatCat贴图
//因为最后使用的是摄像机空间的法线的xy采样，所以法线的取值范围决定了贴图的有效范围是个圆形
//优点：不需要进行一大堆的光照计算，只通过简单的采样一张贴图就可以实现PBR等其他复杂效果
//缺点：因为只是采样一张贴图，所以当灯光改变时效果不会变化，看起来好像一直朝向摄像机，也就是常说的难以使效果与环境产生交互
//可以考虑将复杂的光照信息（例如高光，漫反射）烘焙在MatCap贴图上，然后将环境信息（例如建筑，天空）烘培在CubeMap上，然后将2者结合在一起，多少能弥补一下缺点
//MatCap基于它的效果，很多使用用来低成本的实现车漆，卡通渲染头发的“天使环（angel ring）”等相关效果
Shader "Lakehani/URP/Lighting/MatCap"
{
    Properties
    {
        _MatCapTexture("MatCap Texture", 2D) = "white" {}
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
                float3 normalOS      : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalVS : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _MatCapTexture_ST;
            CBUFFER_END

            TEXTURE2D(_MatCapTexture);SAMPLER(sampler_MatCapTexture);

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);

                //把normal从模型空间转到世界空间
                float3 normalWS =TransformObjectToWorldNormal(IN.normalOS);
                //把世界空间转到摄像机空间,第2个参数true表示函数返回前会做normalize
                OUT.normalVS = TransformWorldToViewDir(normalWS,true);
                //因为后面要用法线作为UV的值来采样，所以需要把法线 -1到1 的范围映射 0到1
                OUT.normalVS = OUT.normalVS * 0.5 + 0.5;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 matcap = SAMPLE_TEXTURE2D(_MatCapTexture, sampler_MatCapTexture, IN.normalVS.xy);
                return matcap;
            }

            ENDHLSL
        }
    }
}
