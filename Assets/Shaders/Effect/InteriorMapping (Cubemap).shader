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

这个仓库有比较复杂和完成的例子，包括模拟窗户的光源投射，物体在假室内移动等
https://github.com/Gaxil/Unity-InteriorMapping


Interior Mapping 包含Cubemap和预投影纹理2个做法的shader代码(原理一样，但我和论坛的写法不同)
https://forum.unity.com/threads/interior-mapping.424676/#post-2751518

代码虽然只写Cubemap用法，但是原理是一样的，这里记录一下常见的做法
* Cubemap
    优点：生成和采样都很简单
    缺点：6个面是固定的无法简单的替换，无法直观的看贴图，如果大量生成不好管理，不适用大规模建筑
* 6个面分成6张贴图
    优点：因为6个面是分离的，所以可以根据需求随意替换
    缺点：如果大量生成，贴图会很散乱，无法直观的看贴图，材质球的操作也非常繁琐，不适用大规模建筑
* 将多个房间的6个面按规则放到一个张图籍上
    优点：因为在一个图集上，所以随机替换和随机组装房间变得非常便捷，可以在大规模建筑使用
    缺点：图集不直观，管理难，如果室内非常复杂，随机替换在室内复杂时随即规则需要额外商量，因为复杂的室内往往6个面是一套的
* 预投影纹理
    优点：因为是把室内预先拍摄到一张图片上的，所以非常直观，同时也可以把多个房间放到一张图集上，管理容易
    缺点：无法方便的随机替换6个面（对于复杂的室内也没必要），变为随机替换一个房间，在深度很深的室内，在采样后在会有失真的问题，在非常偏的视角和上面的比会有一些偏移

    前3个基本一样没什么可以说的
    最后一个预投影纹理看我的 InteriorMapping (Pre-Projected).shader
*/


Shader "Lakehani/URP/Effect/InteriorMapping (Cubemap)"
{
    Properties
    {
        _CubeMap("Room Cubemap", Cube) = "white" {}
        _RoomWidth("Room Width",Float) = 1.0
        _RoomHeight("Room Height", Float) = 1.0
        _RoomDepth("Room Depth", Float) = 1.0
        [Toggle]_TilingMode("Enable Tiling Mode",Float) = 1.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Geometry"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile __ _TILINGMODE_ON

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
            float4 _CubeMap_ST;
            half _RoomWidth;
            half _RoomHeight;
            half _RoomDepth; 
            CBUFFER_END
            TEXTURECUBE(_CubeMap);SAMPLER(sampler_CubeMap);


            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);

                OUT.uv = TRANSFORM_TEX(IN.uv, _CubeMap);

                float3 viewWS = GetWorldSpaceViewDir(positionWS);

                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                //模型空间也可以，但是为了曲面也能有正常效果，所以在切空间下进行
                float3x3 tangentSpaceTransform = float3x3(normalInput.tangentWS,normalInput.bitangentWS,normalInput.normalWS);
                OUT.viewTS = mul(tangentSpaceTransform, viewWS);
                //为了保证调整图片的tiling的时候效果正常，假设tiling.x为2那么需要水平方向放2个房间，相当于视角偏移了
                OUT.viewTS *= _CubeMap_ST.xyx;
                return OUT;
            }


            half4 SimpleCubeInterior(float2 uv,float3 viewTS)
            {
                uv = frac(uv);
                viewTS = - normalize(viewTS);//注意我们需要的是看向目标的向量，顶点着色器传过来的是朝向摄像机的向量，所以加负号反过来
                /*这里是个坑，记录一下备忘，我们的计算是在TNB空间下
                * 现在我们看向一个平面，它的uv是TB，而z是N，N现在朝向我们
                * 因为我们要假的室内，所以我们需要模拟出来一个盒子
                * 这个盒子以uv为xy轴，N为z轴，盒子中心为原点构建出来
                * 然后使用轴对称包围盒（AABB）求交算法找出交点，这个交点就是我们需要的使用的uv
                */
                //因为uv是我们模拟盒子的xy轴，所以将其中心映射到原点，我们要构建一个2x2x2的方盒子
                uv = uv * 2.0 - 1.0;
	            //因为包围盒求交，求的是一个进入点和一个离开点，这里我们直接用当前uv作为xy，z为1作为进入点，相当于我们贴在玻璃上看室内，想象一下现在这个平面和视角的关系，
                //z为什么是1而不是-1，因为TBN空间下，这个面的N是朝向我们的，也就是我们是从z的正半轴向里面看的，所以进入点的z是1
	            float3 pos = float3(uv,1.0);

	            //这里是AABB求交的经典的部分很多算法都会这些写，如果用C#等语言写都会涉及很多if判断，但是这里写的太少了我愣是花了好久才理解。
                //这里有完整的求进入点和离开点的式子找 boxIntersection
                //https://www.iquilezles.org/www/articles/intersectors/intersectors.htm
                //但是我们进入点已经有了，只需要求离开点就好了
                /*
                * 我们捋一下
                * 射线 r = o + t * d
                * o是射线的出发点，d是射线的方向，t是时间，o和d已知，所以我们要求t;
                * 求AABB进入点交点实际上是求射线xyz到包围盒各边最小的距离的最大值
                * 求AABB的离开点是求射线xyz到包围盒各边的最大距离的最小值
                * 说到这个最小值和最大值，我当时默认想到的就是包围盒几个面轴的最大值(1,1,1)和最小值(-1,-1,-1)，但是我忘记了观察点的位置
                * 因为观察点如果变动和观察方向不同，会导致最小值和最大值变化
                * 举个例子：如果我们面对平面，从y>0的地方从上往下看室内，最小值是(1,1,1),但如果从y<0的地方从下往上看室内我们的最小值是(1,-1,1);
                * 所以理解为靠近射线点较近的3各平面的最小值和较远的3个平面的最大值更好一些
                * 如果不理解为什么可以参考 Lecture 13 Ray Tracing 1 0:56:38左右到最后
                * https://www.bilibili.com/video/BV1X7411F744?p=13 
                */
                /*
                * 拆公式，（以下是我个人的理解）因为盒子是我们构造出来的,所以远平面z肯定是-1,但xy可能是1也可能是-1
                * 我们设变量pos为射线的出发点（当然它也是进入点）；设单位向量viewDir为射线的方向
                * tX = (maxX - pos.x) / viewDir.x (maxX = 1或-1)
                * tY = (maxY - pos.y) / viewDir.y (maxY = 1或-1)
                * tZ = (maxZ - pos.z) / viewDir.z (maxZ = -1)
                * 所以 tXYZ = (max - pos) / viewDir 去掉括号让每项除viewDir
                * 【步骤A】得 tXYZ = max/viewDir - pos/viewDir 
                * 得 tMax = min(min(tXYZ.x, tXYZ.y), tXYZ.z); 
                * 所以离开点为 posExit = pos + viewDir * tMax;
                * 结合【步骤A】的max/viewDir中的max.x与viewDir.x 是正负同号的(对于远处3个面是这样的)，其他分量也是，所以分量max/viewDir 3个分量都是正数
                * 所以提出 id = 1.0 / viewDir;  
                * 结合【步骤A】得到 k = abs(max * id) - pos * id; 但是max的3个分量不是1就是-1，再简化
                * 得到 abs(id) - pos * id;
                * 最后求最小值得到tMax
                */
	            float3 id = 1.0 / viewTS;
	            float3 k = abs(id) - pos * id;
	            float kMin = min(min(k.x, k.y), k.z);
	            pos  += kMin * viewTS;

                //求出离开点后，我们把这个pos看做从原点出发的一条向量，然后将z轴翻转一下用于cubemap采样
                pos *= float3(1,1,-1);
                float4 roomColor = SAMPLE_TEXTURECUBE(_CubeMap, sampler_CubeMap,pos);


                return half4(roomColor.rgb, 1.0);
            }

            //该函数提供宽高深的调整，不再描述具体算法过程，具体的参考上面的SimpleCubeInterior函数
            half4 CubeInterior(float2 uv,float3 viewTS,half roomWidth,half roomHeight,half roomDepth)
            {
                uv = frac(uv);
                viewTS = - normalize(viewTS);
          
                uv = uv * 2.0 - 1.0;
                float3 pos = float3(uv,roomDepth);
                
                float3 roomSize = float3(roomWidth,roomHeight,roomDepth);
                
                float3 id = 1.0 / viewTS;
	            float3 k = abs(id) * roomSize - pos * id;
	            float kMin = min(min(k.x, k.y), k.z);
	            pos += kMin * viewTS;
                
                #if defined(_TILINGMODE_ON)
                    //平铺模式
                    //如果能保证roomSize分量一定都是整数可以直接这么算，就一行代码
                    //可以在roomSize声明代码下面用 round cell floor 等等
                    //但我想表现得更好一点，所以用下面的【B】
                    //pos = fmod(pos + roomSize - 0.001,2) - 1;
                    
                    //-------------【B】开始----------------
                    //--- 这里为了更好的平铺我将6个面分开计算
                    //为了方便阅读我用if-else来判断
                    //可以看到要算的轴不同，但是计算过程一样
                    if(pos.y >= roomSize.y-0.001) //上
                    {
                        //因为现在是在每个轴在[-1,1]这个区间，超过这个区域的就算是重复平铺我要将超过[-1,1]范围的数值，再映射回[-1，1]
                        //例如roomSize的宽度变成原来的2倍，那么x轴范围变成[-2,2]
                        //为了方便计算，先将[-2,2]变成[0,4]然后对2求余数，范围变成[0,2],然后-1，范围变成[-1,1]
                        pos.xz = fmod(pos.xz + roomSize.xz,2) - 1;
                        pos.y /= roomSize.y;
                    }
                    else if(pos.y <= 0.001 - roomSize.y) //下
                    {
                        pos.xz = fmod(pos.xz + roomSize.xz,2) - 1;
                        pos.y /= roomSize.y;
                    }
                    else if(pos.x >= roomSize.x -0.001) //右
                    {
                        pos.yz = fmod(pos.yz + roomSize.yz,2) - 1;
                        pos.x /= roomSize.x;
                    }
                    else if(pos.x <= 0.001 - roomSize.x)//左
                    {
                        pos.yz = fmod(pos.yz + roomSize.yz,2) - 1;
                        pos.x /= roomSize.x;
                    }
                    else if(pos.z >= roomSize.z - 0.001) //前
                    {
                        pos.xy = fmod(pos.xy + roomSize.xy,2) - 1;
                        pos.z /= roomSize.z;
                    }
                    else if(pos.z <= 0.001 - roomSize.z)//后
                    {
                        pos.xy = fmod(pos.xy + roomSize.xy,2) - 1;
                        pos.z /= roomSize.z;
                    }
                    //-------------【B】结束----------------
                #else
                    //拉伸模式
                    //因为pos 一定在room的面上，除以roomSize都会全部映射回[-1,1]的范围
                    pos /= roomSize;
                #endif                


                //反转轴向，采样cubemap
                pos *= float3(1.0,1.0,-1.0);
                float4 roomColor = SAMPLE_TEXTURECUBE(_CubeMap, sampler_CubeMap,pos);


                return half4(roomColor.rgb, 1.0);
            }


            half4 frag(Varyings IN) : SV_Target
            {
                
                //half4 roomColor = SimpleCubeInterior(IN.uv,IN.viewTS);

                half4 roomColor = CubeInterior(IN.uv,IN.viewTS,_RoomWidth,_RoomHeight,_RoomDepth);
                return roomColor;
            }

            ENDHLSL
        }
    }
}
