/*高度图（视差映射）的自阴影，因为高度图虽然使凹凸感变强，但是自身突出的部分却不会在自身上有影子
这里使用浮雕来演示，视差遮蔽方法类似，更多关于高度图或者视差映射的东西看Parallax Mapping (HeightMap).shader文件
*/

Shader "Lakehani/URP/Lighting/ParallaxMapping (Self-Shadowing)"
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

        _MinSelfShadowLayerCount("Min Self Shadow Layer Count",int) = 5
        _MaxSelfShadowLayerCount("Max Self Shadow Layer Count",int) = 10

        _ShadowIntensity("Shadow Intensity",Float) = 1
        [Toggle] _SoftShadow("Soft Shadow",Float) = 1
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Geometry"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //关于[Toggle] [ToggleOff]如何使用看官方文档 https://docs.unity3d.com/ScriptReference/MaterialPropertyDrawer.html
            #pragma multi_compile __ _SOFTSHADOW_ON 
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
                float3 lightTS : TEXCOORD6; 
                
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
            int _MinSelfShadowLayerCount;
            int _MaxSelfShadowLayerCount;
            half _ShadowIntensity;
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

            //浮雕映射 Relief Parallax Mapping
            //但是后来出现了一个比2分查找更快的算法 Secant Method - Eric Risser，既 割线法，加速求解
            //URP的也使用了割线法，参考 PerPixelDisplacement.hlsl
            half2 ReliefParallaxMapping(half2 uv, int minNumLayers,int maxNumLayers, half heightScale, half3 viewDirTS,out half outLayerHeight)
            {
                viewDirTS = normalize(viewDirTS);
                outLayerHeight = 0;
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
                    outLayerHeight = intersectionHeight;
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

            half ParallaxSelfShadowing(half2 uv,half layerHeight, int minNumLayers,int maxNumLayers,half heightScale, half3 lightDirTS)
            {
                lightDirTS = normalize(lightDirTS);
                //如果没有点被遮挡的时候应该是1
                half shadowMultiplier = 1;
                if(dot(half3(0, 0, 1), lightDirTS) > 0)
                {
                    half numSamplesUnderSurface = 0;

                    #if defined(_SOFTSHADOW_ON)
                        //因为软阴影下面要取最大值所以设置为0
                        shadowMultiplier = 0;
                    #endif
                    //这里稍微做了一个优化
                    //因为在TBN空间，光线越接近(0,0,1)也就是法线，需要判断的次数也越少
                    half numLayers = lerp((half)maxNumLayers,(half)minNumLayers,abs(dot(half3(0.0, 0.0, 1.0), lightDirTS)));
                    //高度图整体范围 [0,1]
                    //numLayers 表示分了多少层
                    //stepSize 每层的间隔
                    //重新分层是从视差映射得到的结果开始分层，所以这里不是1/numLayers，而我是当作高度图，所以用1减去
                    //------------------ 1
                    //
                    //------------------ 0
                    half stepSize = (1 - layerHeight) / numLayers;
                    //因为我们要找被多少层挡住了，所以直接延光源方向找，所以不需要除-z（不需要反转光源方向）
                    half2 parallaxMaxOffsetTS = (lightDirTS.xy / lightDirTS.z)* heightScale;
                    //求出每一层的偏移，然后我们要逐层判断
                    half2 uvOffsetPerStep = stepSize * parallaxMaxOffsetTS;

                    //初始化当前偏移
                    half2 uvOffsetCurrent = uv + uvOffsetPerStep;
                    //GetParallaxMapHeight是自定义函数就在该文件的上面
                    half currMapHeight = GetParallaxMapHeight(uvOffsetCurrent);
                    half currLayerHeight = layerHeight + stepSize;

                    #if defined(_SOFTSHADOW_ON)
                        int shadowStepIndex = 1;
                    #endif

                    //unable to unroll loop, loop does not appear to terminate in a timely manner
                    //上面这个错误是在循环内使用tex2D导致的，需要加上unroll来限制循环次数或者改用tex2Dlod
                    for (int stepIndex = 0; stepIndex < numLayers; ++stepIndex)
                    {
                        if (currLayerHeight >0.99)
                            break;

                        if(currMapHeight > currLayerHeight)
                        {
                            //防止在0到1范围外的影子出现，如果不处理当影子较长时边缘会有多余的影子
                            if(uvOffsetCurrent.x >= 0 && uvOffsetCurrent.x <= 1.0 && uvOffsetCurrent.y >= 0 &&uvOffsetCurrent.y <= 1.0)
                            {
                                numSamplesUnderSurface += 1; //被遮挡的层数
                            #if defined(_SOFTSHADOW_ON) 
                                //想象一下软阴影的特征，越靠近边缘，影子越浅
                                half newShadowMultiplier = (currMapHeight - currLayerHeight) * (1 - shadowStepIndex / numLayers);
                                shadowMultiplier = max(shadowMultiplier, newShadowMultiplier);
                            #endif
                            }
                        }

                        #if defined(_SOFTSHADOW_ON)
                            shadowStepIndex += 1;
                        #endif

                        currLayerHeight += stepSize;
                        uvOffsetCurrent += uvOffsetPerStep;

                        currMapHeight = GetParallaxMapHeight(uvOffsetCurrent);
                    }
                    #if defined(_SOFTSHADOW_ON)
                        shadowMultiplier = numSamplesUnderSurface < 1 ? 1.0 :(1 - shadowMultiplier);
                    #else
                        shadowMultiplier = 1 - numSamplesUnderSurface / numLayers; //根据被遮挡的层数来决定阴影深浅
                    #endif

                    
                }
                return shadowMultiplier;
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

                Light light = GetMainLight();
                OUT.lightTS = mul(tangentSpaceTransform, light.direction);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {

                //视差贴图处理
                half outLayerHeight;
                half2 finalUV = ReliefParallaxMapping(IN.uv,_MinLayerCount,_MaxLayerCount,_ParallaxScale,IN.viewTS,outLayerHeight);

                //这个作用本质上就是裁掉周围的东西，因为如果图片的Wrap Mode 设置的是Repeat模式，你会在边缘看到重复平铺的图像
                if(finalUV.x > 1.0 || finalUV.y > 1.0 || finalUV.x < 0.0 || finalUV.y < 0.0) //去掉边上的一些古怪的失真
                    discard;
                
                //视差自阴影处理
                half shadowMultiplier = ParallaxSelfShadowing(finalUV,outLayerHeight,_MinSelfShadowLayerCount,_MaxSelfShadowLayerCount,_ParallaxScale,IN.lightTS);

                
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
                half3 totalColor = ambientColor + (diffuseColor + specularColor) * pow(abs(shadowMultiplier),_ShadowIntensity);

                return half4(totalColor.rgb,1);
            }

            ENDHLSL
        }
    }
}
