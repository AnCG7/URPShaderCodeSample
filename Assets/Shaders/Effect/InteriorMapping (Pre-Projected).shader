/*
Interior Mapping
核心2个点
视角向量与模拟构造的AABB盒子求交点
对求出的交点变换采样贴图
https://zhuanlan.zhihu.com/p/376762518

//各种包围盒交点
https://www.iquilezles.org/www/articles/intersectors/intersectors.htm

//AABB求交的一个容易理解教程
https://www.bilibili.com/video/BV1X7411F744?p=13 
Lecture 13 Ray Tracing 1 
0:56:38左右到最后

//模拟城市5(SimCity 5)使用的预投影
https://hanecci.hatenadiary.org/entries/2013/12/04
http://www.andrewwillmott.com/talks/from-aaa-to-indie


极限竞速：地平线4 使用的预投影
https://www.artstation.com/artwork/Pm2wo4

//另一个简明的参考教程
https://andrewgotow.com/2018/09/09/interior-mapping-part-2/

Interior Mapping 包含Cubemap和预投影纹理2个做法的shader代码(原理一样，但我和论坛的写法不同)
https://forum.unity.com/threads/interior-mapping.424676/#post-2751518
*/

Shader "Lakehani/URP/Effect/InteriorMapping (Pre-Projected)"
{
    Properties
    {
        _ProjectRoomMap("Pre-Projected Room Map", 2D) = "white" {}
        _ProjectCameraFOV("Pre-Projected Camera FOV", range(0.001,180)) = 60
        _ProjectRoomDepth("Pre-Projected Room Depth", Float) = 1.0
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
                float4 tangentOS     : TANGENT;
                float2 uv:TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv:TEXCOORD0;
                float3 viewTS : TEXCOORD1;
                
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _ProjectRoomMap_ST;
            half _ProjectCameraFOV;
            half _ProjectRoomDepth;
            CBUFFER_END
            TEXTURE2D(_ProjectRoomMap);SAMPLER(sampler_ProjectRoomMap);

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);

                OUT.uv = TRANSFORM_TEX(IN.uv, _ProjectRoomMap);

                float3 viewWS = GetWorldSpaceViewDir(positionWS);

                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                float3x3 tangentSpaceTransform = float3x3(normalInput.tangentWS,normalInput.bitangentWS,normalInput.normalWS);
                OUT.viewTS = mul(tangentSpaceTransform, viewWS);
                //为了保证调整图片的tiling的时候效果正常，假设tiling.x为2那么需要水平方向放2个cube，viewTS.x同样需要向x轴偏移
                OUT.viewTS *= _ProjectRoomMap_ST.xyx;
                return OUT;
            }

            //我们使用的Texture是预投影的，所以纹理已经被透视投影处理过了，我们依旧对模拟的房间盒子求交，然后对这个预透视投影的图片进行采样
            //projectCameraFOV 生成预投影纹理时的相机的FOV
            //projectRoomDepth 生成预投影纹理时的房间的深度
            //其他解释参考 InteriorMapping (Cubemap).shader
            half4 PreProjectedInterior(float2 uv,float3 viewTS,half projectCameraFOV,half projectRoomDepth)
            {
                uv = frac(uv);
                viewTS = - normalize(viewTS);

                //构造一个原点在中心(0,0,0)的2x2x2的盒子，我们可以改变盒子深度（宽高也可以，但为了方面理解，这里只改变深度）
                float3 pos = float3(uv * 2 - 1, projectRoomDepth);
                float3 roomSizeScale = float3(1,1,projectRoomDepth);

                float3 id = 1.0 / viewTS;
                float3 k = abs(id) * roomSizeScale - pos * id;
                float kMin = min(min(k.x, k.y), k.z);
                pos += kMin * viewTS;
                
                //将原来[-roomDepth,roomDepth]的范围映射到[0.0,2 * roomDepth]表示在当前盒子的真实深度
                float realZLength = pos.z + projectRoomDepth;
                //这里我没有按照难懂的假设53.13的FOV和lerp来采样
                //我们的纹理是预投影的，如果要采样就需要原来投影这个图片的相机的FOV
                //所以假设房间的近平面（距离观察点最近的正对我们的那个面）作为相机的near而远面作为相机的far，因为预投影时使用的相机和这个类似，这里尝试自己预投影一下就理解了
                //然后我们使用预投影相机的FOV和上面的near和far可以构建出一个视锥体（Frustum），然后看一半，因为对称关系（最好画个图），别忘记例子只改深度，宽高依旧是个正方形，比例是一样的
                //然后我们根据在盒子内交点的z左边可以根据fov/2的角度求出盒子远面与视锥体的交点，再压缩回盒子内部，就可以正常采样到预投影的图片中，原本的uv
                //举个例子，为什么很多demo用的是53.13，因为想要预投影后，房间远面占整个纹理的一半既0.5
                //如果单看盒子上半部分，盒子高度是1，想要房间远面是整体的一半，就需要远面和预投影相机视锥体能在高度2这个点相交
                //因为1/（1+1）= 0.5，因为约等于tan(26.565°)所以fov = 26.565°* 2 = 53.13°
                //如果预投影的相机FOV是确定的那么下面写法可以简化
                float interp = 1 / (tan(radians(projectCameraFOV / 2)) * (2 * projectRoomDepth - realZLength) + 1 );
                float2 interiorUV = pos.xy * interp;

                interiorUV = interiorUV * 0.5 + 0.5;
                 
                return SAMPLE_TEXTURE2D(_ProjectRoomMap,sampler_ProjectRoomMap,interiorUV);
              
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 roomColor = PreProjectedInterior(IN.uv,IN.viewTS,_ProjectCameraFOV,_ProjectRoomDepth);
                return roomColor;
            }

            ENDHLSL
        }
    }
}
