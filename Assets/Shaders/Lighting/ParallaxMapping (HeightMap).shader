/*高度图或者说视差映射，法线贴图主要的目的是描述物体的光照，视差贴图主要描述的是物体的遮挡情况，可以使物体表面的凹凸和光照更加真实，特别在视角与法线夹角变大时。
常见的的视差映射方法（也是本文件实现了的方法）
简单的视差映射 Parallax Mapping（效果不好，但是计算超级简单，如果你只想要有那么一点点效果可以用这个）
陡峭视差映射 Steep Parallax Mapping (raymarch思想的步进法线性查找，不常用，因为下面2个都是对这个方法的优化)
视差遮蔽映射 Parallax Occlusion Mapping (简称：POM)(这个比较常用是对陡峭视差的优化实现，本质上之比陡峭视差多了一步插值)
浮雕映射 Relief Parallax Mapping（这个比较常用是对陡峭视差的优化实现，本质上只比陡峭视差多了一步二分查找或者割线法查找）
浮雕映射比视差遮蔽映射多了额外的二分查找，所以和其一样的线性插值部分步进数量可以小一些来节省开销。而二分查找提高精确度，所以理论上比视差遮蔽映射更好，但是开销更大
浮雕映射后来出现了割线法，割线法有着比二分查找更快的收敛速度，即使用非常少查找次数，就可以得到很好的精度，虽然还是比视差遮蔽映射稍微费一点（该文件使用割线法而不是二分查找）

另外还有很多其他的视差映射
Cone Step Mapping
View-Dependent Displacement Mapping
Distance Mapping
等等

主要原理参考资料
但是该文章把高度图作为深度图反着使用，让我很捉急，但也确实是交代的比较清晰完整的资料
https://learnopengl-cn.github.io/05%20Advanced%20Lighting/05%20Parallax%20Mapping/
https://zhuanlan.zhihu.com/p/319769756
URP本身的ParallaxMapping.hlsl文件以及ShaderGraph本身的ParallaxMapping和ParallaxOcclusionMapping节点生成的代码也是很好的学习资料就是有点费脑子和眼睛
扩展知识
http://ma-yidong.com/2019/06/22/a-short-history-of-parallax-occlusion-mapping-relief-mapping/
*/


Shader "Lakehani/URP/Lighting/ParallaxMapping"
{
    Properties
    {
        _BaseMap("Base", 2D) = "white" {}
        _BaseColor("Color", Color) = (1,1,1,1)

        _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Scale",float) = 1.0

        _ParallaxMap("Height Map", 2D) = "black" {}
        _ParallaxScale("Parallax Scale", float) = 0.01
        _MinLayerCount("Min Layer Count",int) = 5
        _MaxLayerCount("Max Layer Count",int) = 20

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
                float3 normalWS : TEXCOORD1;    
                float3 tangentWS : TEXCOORD2;   
                float3 bitangentWS : TEXCOORD3; 
                float3 viewWS : TEXCOORD4; 

                float3 viewTS : TEXCOORD5; 
                
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            float4 _BumpMap_ST;
            half _BumpScale;
            float4 _ParallaxMap_ST;
            half _ParallaxScale;
            int _MinLayerCount;
            int _MaxLayerCount;
            CBUFFER_END
            TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);SAMPLER(sampler_BumpMap);
            TEXTURE2D(_ParallaxMap);SAMPLER(sampler_ParallaxMap);

            half GetParallaxMapHeight(half2 uv)
            {
                //具体参见 ParallaxMapping.hlsl的ParallaxMapping函数
                half lod = 0;
                return SAMPLE_TEXTURE2D_LOD(_ParallaxMap, sampler_ParallaxMap, uv,lod).r;
            }


            //简单的视差映射 参考ParallaxMapping.hlsl中的ParallaxOffset1Step函数
            //Unity URP中的计算方式 amplitude参数解释为应用于Heightmap高度的乘数，等同与下面自定函数中的heightScale的作用
            //amplitude的建议值是[0.005,0.08]
            //注意实际上URP的做法个人感觉要比很多资料中直接乘以一个scale要好得多
            //但是为了方便对比学习，之后的函数依旧是使用heightScale而不是amplitude
            half2 URPParallaxMapping(half2 uv, half amplitude, half3 viewDirTS)
            {
                half height = GetParallaxMapHeight(uv);
                //amplitude如果等于0.08，那么height的范围是[0,1]，正好最后计算后的height的范围是[-0.04,0.04]
                //这可能也是为什么叫amplitude（振幅）的原因
                height = height * amplitude - amplitude / 2.0;
                half3 v = normalize(viewDirTS);
                v.z += 0.42;
                half2 uvOffset = height * (v.xy / v.z);
                return uv + uvOffset;
            }

            //简单的视差映射 Parallax Mapping
            //可以看到简单的视察映射，并不会消耗太多的性能，但是效果要大打折扣
            //当高度较为陡峭视角与表面角度较大时，会出现明显的走样
            half2 ParallaxMapping(half2 uv, half heightScale, half3 viewDirTS)
            {
                half height = GetParallaxMapHeight(uv);
                half3 v = normalize(viewDirTS);
                //这里v.xy/v.z,并不是一定要除z。想象一下在TBN空间下，z越大视角越接近法线，所需要的偏移越小，如果视角与法线平行说明可以指直接看到，不需要偏移了;
                //同样的当视角与法线接近垂直的时候，z接近无限小,从而增加纹理坐标的偏移；这样做在视角上会获得更大的真实度。
                //但也会因为在某些角度看会不好看所以也可以不除z，不除z的技术叫做 Parallax Mapping with Offset Limiting（有偏移量限制的视差贴图）
                half2 uvOffset = v.xy / v.z * (height * heightScale);
                return uv + uvOffset;
            }

            //陡峭视差映射 Steep Parallax Mapping
            //我在URP的PerPixelDisplacement.hlsl找到了相关实现
            //使用raymarch也就是步进采样法，从摄像机开始往下找，也就是从上往下找
            //因为上面的简单的视差是直接近似，所以在高度陡峭变化的情况下效果不好，这次我们把高度分层，寻找最接近的位置，而不是直接使用近似值
            //提高采样数量提高精确性
            //层数越多结果越准确，性能消耗也越大
            half2 SteepParallaxMapping(half2 uv, int numLayers, half heightScale, half3 viewDirTS)
            {
                //高度图整体范围 [0,1]
                //numLayers 表示分了多少层
                //stepSize 每层的间隔
                viewDirTS = normalize(viewDirTS);
                half stepSize = 1.0 / (half)numLayers;
                //这一步和简单的视差映射一样
                //但是我们想要从视角往下找,视角向量是一个指向视点的向量，我们想要从视点开始找
                //所以这里除以的-z，但是无所谓反正把视角向量反过来就行
                half2 parallaxMaxOffsetTS = (viewDirTS.xy / -viewDirTS.z)* heightScale;
                //求出每一层的偏移，然后我们要逐层判断
                half2 uvOffsetPerStep = stepSize * parallaxMaxOffsetTS;

                //初始化当前偏移
                half2 uvOffsetCurrent = uv;
                //GetParallaxMapHeight是自定义函数就在该文件的上面
                half prevMapHeight = GetParallaxMapHeight(uvOffsetCurrent);
                uvOffsetCurrent += uvOffsetPerStep;
                half currMapHeight = GetParallaxMapHeight(uvOffsetCurrent);
                half layerHeight = 1 - stepSize; 

                //遍历所有层查找估计偏差点（采样高度图得到的uv点的高度 > 层高的点）
                //unable to unroll loop, loop does not appear to terminate in a timely manner
                //上面这个错误是在循环内使用tex2D导致的，需要加上unroll来限制循环次数或者改用tex2Dlod
                for (int stepIndex = 0; stepIndex < numLayers; ++stepIndex)
                {
                    //我们找到了估计偏差点
                    if (currMapHeight > layerHeight)
                        break;

                    prevMapHeight = currMapHeight;
                    layerHeight -= stepSize;
                    uvOffsetCurrent += uvOffsetPerStep;

                    currMapHeight = GetParallaxMapHeight(uvOffsetCurrent);
                }
                return uvOffsetCurrent;
            }

            //视差遮蔽映射 Parallax Occlusion Mapping (POM)
            //我在URP的 PerPixelDisplacement.hlsl找到了相关实现
            //你会发现陡峭视差映射，其实也有问题，结果不应该直接就用找到的估计偏差点
            //因为我们知道准确的偏移在 估计偏差点和估计偏差点的前一个点之间
            //所以我们可以插值这2个点来得到更好的结果。
            half2 ParallaxOcclusionMapping(half2 uv, int minNumLayers,int maxNumLayers, half heightScale, half3 viewDirTS)
            {
                viewDirTS = normalize(viewDirTS);
                //这里稍微做了一个优化
                //因为在TBN空间，视角越接近(0,0,1)也就是法线，需要采样的次数越少
                half numLayers = lerp((half)maxNumLayers,(half)minNumLayers,abs(dot(half3(0.0, 0.0, 1.0), viewDirTS)));
                //这个部分和SteepParallaxMapping上面的一模一样（为了方便阅读我直接复制粘贴，没有用函数包装）
                ////-----------------------------------SteepParallaxMapping（陡峭视差映射）一模一样 |开始|-------------------
                 //高度图整体范围 [0,1]
                //numLayers 表示分了多少层
                //stepSize 每层的间隔
                half stepSize = 1.0 / numLayers;
                //这一步和简单的视差映射一样
                //但是我们想要从视角往下找,视角向量是一个指向视点的向量，我们想要从视点开始找
                //所以这里除以的-z，但是无所谓反正把视角向量反过来就行
                half2 parallaxMaxOffsetTS = (viewDirTS.xy / -viewDirTS.z)* heightScale;
                //求出每一层的偏移，然后我们要逐层判断
                half2 uvOffsetPerStep = stepSize * parallaxMaxOffsetTS;

                //初始化当前偏移
                half2 uvOffsetCurrent = uv;
                //GetParallaxMapHeight是自定义函数就在该文件的上面
                half prevMapHeight = GetParallaxMapHeight(uvOffsetCurrent);
                uvOffsetCurrent += uvOffsetPerStep;
                half currMapHeight = GetParallaxMapHeight(uvOffsetCurrent);
                half layerHeight = 1 - stepSize; 

                //遍历所有层查找估计偏差点（采样高度图得到的uv点的高度 > 层高的点）
                //unable to unroll loop, loop does not appear to terminate in a timely manner
                //上面这个错误是在循环内使用tex2D导致的，需要加上unroll来限制循环次数或者改用tex2Dlod
                for (int stepIndex = 0; stepIndex < numLayers; ++stepIndex)
                {
                    //我们找到了估计偏差点
                    if (currMapHeight > layerHeight)
                        break;

                    prevMapHeight = currMapHeight;
                    layerHeight -= stepSize;
                    uvOffsetCurrent += uvOffsetPerStep;

                    currMapHeight = GetParallaxMapHeight(uvOffsetCurrent);
                }
                ////-----------------------------------SteepParallaxMapping（陡峭视差映射）一模一样 |结束|-------------------


                //线性插值
                half delta0 = currMapHeight - layerHeight;
                half delta1 = (layerHeight + stepSize) - prevMapHeight;
                half ratio = delta0 / (delta0 + delta1);
                //这里就是比较常见的插值写法。
                //uvOffsetCurrent - uvOffsetPerStep 表示上一步的偏移
                //half2 finalOffset = (uvOffsetCurrent - uvOffsetPerStep) * ratio + uvOffsetCurrent * (1 - ratio);
                //这里是URP里面的写法（算是一个小优化，其实就是化简上面这个式子）
                half2 finalOffset = uvOffsetCurrent - ratio * uvOffsetPerStep;
                
                return finalOffset;
            }

            //浮雕映射 Relief Parallax Mapping
            //浮雕映射和上面的视差遮蔽映射，思路一样，也同样是在陡峭视差映射的基础上完成的
            //一般来说在找到估计偏差点后，在当前层高中使用2分查询来找到最优点（等同于在一个层高内再次细分），而视差遮蔽映射使用的是直接根据权重插值
            //所以浮雕映射效果优于视差遮蔽映射，但是视差遮蔽映射比浮雕映射快
            //但是后来出现了一个比2分查找更快的算法 Secant Method - Eric Risser，既 割线法，加速求解
            //URP的也使用了割线法，参考 PerPixelDisplacement.hlsl
            half2 ReliefParallaxMapping(half2 uv, int minNumLayers,int maxNumLayers, half heightScale, half3 viewDirTS)
            {
                viewDirTS = normalize(viewDirTS);
                //这里稍微做了一个优化
                //因为在TBN空间，视角越接近(0,0,1)也就是法线，需要采样的次数越少
                half numLayers = lerp((half)maxNumLayers,(half)minNumLayers,abs(dot(half3(0.0, 0.0, 1.0), viewDirTS)));
                //这个部分和SteepParallaxMapping上面的一模一样（为了方便阅读我直接复制粘贴，没有用函数包装）
                ////-----------------------------------SteepParallaxMapping（陡峭视差映射）一模一样 |开始|-------------------
                 //高度图整体范围 [0,1]
                //numLayers 表示分了多少层
                //stepSize 每层的间隔
                half stepSize = 1.0 / numLayers;
                //这一步和简单的视差映射一样
                //但是我们想要从视角往下找,视角向量是一个指向视点的向量，我们想要从视点开始找
                //所以这里除以的-z，但是无所谓反正把视角向量反过来就行
                half2 parallaxMaxOffsetTS = (viewDirTS.xy / -viewDirTS.z)* heightScale;
                //求出每一层的偏移，然后我们要逐层判断
                half2 uvOffsetPerStep = stepSize * parallaxMaxOffsetTS;

                //初始化当前偏移
                half2 uvOffsetCurrent = uv;
                //GetParallaxMapHeight是自定义函数就在该文件的上面
                half prevMapHeight = GetParallaxMapHeight(uvOffsetCurrent);
                uvOffsetCurrent += uvOffsetPerStep;
                half currMapHeight = GetParallaxMapHeight(uvOffsetCurrent);
                half layerHeight = 1 - stepSize; 

                //遍历所有层查找估计偏差点（采样高度图得到的uv点的高度 > 层高的点）
                //unable to unroll loop, loop does not appear to terminate in a timely manner
                //上面这个错误是在循环内使用tex2D导致的，需要加上unroll来限制循环次数或者改用tex2Dlod
                for (int stepIndex = 0; stepIndex < numLayers; ++stepIndex)
                {
                    //我们找到了估计偏差点
                    if (currMapHeight > layerHeight)
                        break;

                    prevMapHeight = currMapHeight;
                    layerHeight -= stepSize;
                    uvOffsetCurrent += uvOffsetPerStep;

                    currMapHeight = GetParallaxMapHeight(uvOffsetCurrent);
                }
                ////-----------------------------------SteepParallaxMapping（陡峭视差映射）一模一样 |结束|-------------------

                //一般来说这里应该指定一个查询次数,用二分法查询，但是后来出现了割线法，可以更加快速近似

                half pt0 = layerHeight + stepSize;
                half pt1 = layerHeight;
                half delta0 = pt0 - prevMapHeight;
                half delta1 = pt1 - currMapHeight;

                half delta;
                half2 finalOffset;


                // Secant method to affine the search
                // Ref: Faster Relief Mapping Using the Secant Method - Eric Risser
                // Secant Method - Eric Risser，割线法
                for (int i = 0; i < 3; ++i)
                {
                    // intersectionHeight is the height [0..1] for the intersection between view ray and heightfield line
                    half intersectionHeight = (pt0 * delta1 - pt1 * delta0) / (delta1 - delta0);
                    // Retrieve offset require to find this intersectionHeight
                    finalOffset = (1 - intersectionHeight) * uvOffsetPerStep * numLayers;

                    currMapHeight = GetParallaxMapHeight(uv + finalOffset);

                    delta = intersectionHeight - currMapHeight;

                    if (abs(delta) <= 0.01)
                        break;

                    // intersectionHeight < currHeight => new lower bounds
                    if (delta < 0.0)
                    {
                        delta1 = delta;
                        pt1 = intersectionHeight;
                    }
                    else
                    {
                        delta0 = delta;
                        pt0 = intersectionHeight;
                    }
                }
                
                return uv + finalOffset;
            }



            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);

                OUT.uv = TRANSFORM_TEX(IN.uv, _BumpMap);

                OUT.viewWS = GetWorldSpaceViewDir(positionWS);

                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.normalWS = normalInput.normalWS;
                OUT.tangentWS = normalInput.tangentWS;
                OUT.bitangentWS = normalInput.bitangentWS;

                float3x3 tangentSpaceTransform =     float3x3(normalInput.tangentWS,normalInput.bitangentWS,normalInput.normalWS);
                OUT.viewTS = mul(tangentSpaceTransform,  OUT.viewWS);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {

                //视差贴图处理
                //URP的几个标准shader，建议第2个参数_ParallaxScale的值是[0.005,0.08]，当然你可以任意调整，会有神奇的效果
                //half2 finalUV = URPParallaxMapping(IN.uv,_ParallaxScale,IN.viewTS);
                //当高度陡峭过大时，可以看到明显的走样
                //half2 finalUV = ParallaxMapping(IN.uv,_ParallaxScale,IN.viewTS);
                //half2 finalUV = SteepParallaxMapping(IN.uv,_MinLayerCount,_ParallaxScale,IN.viewTS);
                //half2 finalUV = ParallaxOcclusionMapping(IN.uv,_MinLayerCount,_MaxLayerCount,_ParallaxScale,IN.viewTS);
                half2 finalUV = ReliefParallaxMapping(IN.uv,_MinLayerCount,_MaxLayerCount,_ParallaxScale,IN.viewTS);
                //这个作用本质上就是裁掉周围的东西，因为如果图片的Wrap Mode 设置的是Repeat模式，你会在边缘看到重复平铺的图像
                if(finalUV.x > 1.0 || finalUV.y > 1.0 || finalUV.x < 0.0 || finalUV.y < 0.0) //去掉边上的一些古怪的失真
					discard;

                //基础颜色贴图处理
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap,finalUV)* _BaseColor;

                //法线贴图处理
                //也可以直接使用宏SampleNormal，但是需要自己加宏定义，具体见 SurfaceInput.hlsl 
                half4 n = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap,finalUV);
                half3 normalTS = UnpackNormalScale(n, _BumpScale);
                half3 normalWS = TransformTangentToWorld(normalTS,half3x3(IN.tangentWS.xyz, IN.bitangentWS.xyz, IN.normalWS.xyz));
                normalWS = normalize(normalWS);
                half3 viewWS = SafeNormalize(IN.viewWS);
                
    
                //光照处理 正常的Lambert漫反射和Blinn-Phong高光
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                half smoothness = exp2(10 * 0.5 + 1);

                half3 ambientColor = unity_AmbientSky.rgb * baseColor.rgb;
                half3 specularColor = LightingSpecular(lightColor, light.direction, normalWS, viewWS, half4(1,1,1,1), smoothness);
                half3 diffuseColor = LightingLambert(lightColor,light.direction,normalWS) * baseColor.rgb;
                half3 totalColor = diffuseColor + specularColor + ambientColor;

                return half4(totalColor.rgb,1);
            }

            ENDHLSL
        }
    }
}
