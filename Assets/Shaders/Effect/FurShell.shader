//使用壳的方式实现毛发效果
//原理：在原始的模型基础上生成和原始模型一样但是大小更大的模型包裹原始模型，这就是壳
//本质上是使用多个层，每层都会比上一层的模型大小更大，每层之间有一个小的间距
//利用这些层和噪波纹理以逼近的方式模拟毛发，所以如果层数不够或间距过大，靠近时会看到明显的分层问题
//我提供了FurLayer200 200层和 FurLayer10 10层 2个模型，场景展示的是200层的模型
//配合Lakehani/URP/Effect/Fur Base类比皮肤的基础颜色作为打底
//因为是逼近的方式模拟，所以每层需要设定一个层系数用来标记层的偏移，后续计算时会用到,一般从最内层到最外层的范围为(0,1]，0是皮肤所以一般不会取0，我这里都是从0.1开始
//因为毛发需要透明队列，基础皮肤颜色层需要在几何队列，另外两者的深度检测不同，所以无法在一个pass完成

//优化手段：壳的方法会有多层壳，使用多Pass或者手动复制模型并为每层模型单独创建材质，都可以手动调整每层的间距和大小以及设置层的系数，但是这样会比较麻烦，如果层数过多性能也会出问题
//我这里在Blender中直接生成了指定层数、等间距和层系数的一个模型，层系数被存储在顶点色的R通道，计算时可以直接获取，这样子使用一个pass就可以直接计算了
//打开根目录ArtSrc文件夹，找到Fur.blend文件，打开后点击 脚本 选项，就能看到脚本，感兴趣可以自己看看
//除了在DCC软件中直接生成，也可以使用GPU Instancing来优化实现

//如果噪波密度和_BaseMap看起来不是很对应的话，可以调整_FurNoiseMap的Tiling

//参考资料：
//https://xbdev.net/directx3dx/specialX/Fur/index.php
//https://mp.weixin.qq.com/s/aIWMEO5Qa2gNn2yCmnHbOg
//https://blog.csdn.net/qq_40924071/article/details/131614202
//https://zhuanlan.zhihu.com/p/378015611
//https://github.com/Acshy/FurShaderUnity

Shader "Lakehani/URP/Effect/Fur Shell"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _BaseMap("Base Map", 2D) = "white" {}
        _FurNoiseMap("Fur Noise Map", 2D) = "white" {}
        _FurNoiseDensity("Fur Noise Density",Float) = 1
        _UVOffset ("UV Offset",Vector) = (0,0,0,0)
        _FurDensity("Fur Density",Range(0,1)) = 1
        _FurThickness("Fur Thickness",Range(0,1)) = 1
        _RimColor ("Rim Color", Color) = (1,1,1,1)
        _RimPower("Rim Power",Float) = 1
        _Occlusion("Occlusion",Range(0,1)) = 1
        _DiffuseOffset("Diffuse Offset", Float) = 0.0
        _SpecularColor ("SpecularColor", Color) = (1,1,1,1)
        _SpecularRange ("Specular Range",  float) = 1
        _SpecularDensity ("Specular Density",  float) = 1
        _Shift("Shift",float) = 0
        _VertexOffset ("Vertex Offset",Vector) = (0,-1,0,0)
        _VertexOffsetScale("Vertex Offset Scale",Float) = 1
        
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Transparent"}

        Pass
        {
            Cull Back 
            ZWrite On
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS      : NORMAL;
                float4 color        : COLOR; // 添加顶点颜色
                float4 tangentOS : TANGENT;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 furUV           : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 viewWS : TEXCOORD3;
                float4 color : TEXCOORD4; // 添加顶点颜色变量
                float3 bitangentWS : TEXCOORD5; 
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _FurNoiseMap_ST;
            half4 _RimColor;
            half _RimPower;
            half4 _BaseColor;
            half _VertexOffsetScale;
            half _FurDensity;
            half _Occlusion;
            half _FurNoiseDensity;
            half _FurThickness;
            half4 _VertexOffset;
            half4 _UVOffset;
            half _DiffuseOffset;
            half4 _SpecularColor;
            half _SpecularRange;
            half _SpecularDensity;
            half _Shift;
            CBUFFER_END
            TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
            TEXTURE2D(_FurNoiseMap);SAMPLER(sampler_FurNoiseMap);
  

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                //我将shell的层系数直接在顶点色R通道里，我直接做了一个多层的模型，每次的R通道单独赋值，从0.1到1.0
                half layerFactor = IN.color.r;

                //加入偏移，使毛发可以有实际的方向偏移，_VertexOffset可以认为给毛发加了一个力，y = -1，就是向下垂
                _VertexOffset *= 0.1;//方便数值的调整
                positionWS += clamp(_VertexOffset.xyz, -1, 1) * pow(layerFactor, 3) * _VertexOffsetScale;
                
                //给uv添加偏移，让毛发有扭曲不太规则的感觉
                float2 uvoffset = _UVOffset.xy  * layerFactor;
                uvoffset *=  0.1 ; //方便数值的调整
                
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS = normalInput.normalWS;
                OUT.bitangentWS = normalInput.bitangentWS;
                OUT.viewWS = GetWorldSpaceViewDir(positionWS);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap) + uvoffset;
                OUT.furUV = TRANSFORM_TEX(IN.uv, _FurNoiseMap) + uvoffset;
                OUT.color = IN.color;
                return OUT;
            }
            //-----------以下是各向异性高光，具体解释可以看Lakehani/URP/Lighting/Anisotropic
            //注意是副切线不是切线，也就是切线空间 TBN 中的 B
            half3 ShiftTangent(half3 bitangentWS,half3 normalWS,half shift)
            {
                half3 shiftedT = bitangentWS + shift * normalWS;
                return normalize(shiftedT);
            }

            half StrandSpecular(half3 bitangentWS,half3 viewDirWS,half3 lightDirWS,half exponent)
            {
                half3 H = normalize(lightDirWS + viewDirWS);
                half dotTH = dot(bitangentWS,H); // 点乘 计算出来的是2个单位向量的cos的值
                half sinTH = sqrt(1.0 - dotTH * dotTH);//因为 sin^2 + cos^2 = 1 所以 sin = sqrt(1 - cos^2);
                half dirAttenuation = smoothstep(-1.0,0.0,dotTH);
                return dirAttenuation * pow(sinTH,exponent);
            }
            //-------------------------------------------------

            half3 LightingHair(half3 bitangentWS, half3 lightDirWS, half3 normalWS, half3 viewDirWS,half exp,half3 specular)
            {
                //这里t可以来2层
                //shift tangents
                half3 t1 = ShiftTangent(bitangentWS,normalWS,_Shift);
                //specular
                half3 specularColor  = StrandSpecular(t1,viewDirWS,lightDirWS,exp) * specular;
                return specularColor;
            }
            
            half4 frag(Varyings IN) : SV_Target
            {

                half layerFactor = IN.color.r;
                
                Light light = GetMainLight();
                half3 lightColor = light.color * light.distanceAttenuation;
                half3 normalWS = normalize(IN.normalWS);
                half3 bitangentWS = normalize(IN.bitangentWS);
                half3 viewWS =  SafeNormalize(IN.viewWS);
                half3 lightWS = light.direction;
                
                half noise = SAMPLE_TEXTURE2D(_FurNoiseMap, sampler_FurNoiseMap, IN.furUV * _FurNoiseDensity).r;
                //简单的做法就是对应噪声纹理的结果，原理上alpha和层系数相关，越靠近外层透明度越高，层次感会变强
                // half alpha = saturate(noise - layerFactor);
                //毛发会变的粗一些，密度看起来会大一些
                half thickness = 1 - _FurThickness;
                half alpha = saturate(noise * 2 - (layerFactor * layerFactor + thickness) * _FurDensity);
                
                //物体的颜色越浅，AO颜色越浅；反之颜色越深，AO颜色越深
                //遮蔽模拟根据阈值简单计算遮蔽，靠近根部越遮蔽越强 _Occlusion = 1，根部就是黑色了
                half occlusion =  lerp(1.0 -_Occlusion,1.0,layerFactor * layerFactor); //这里layerFactor的平方是为了使AO更加明显
                //获取环境光
                half3 ambientColor = SampleSH(normalWS);
                //获取基础色
                half3 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv).rgb * _BaseColor.rgb;
                //计算漫反射HalfLambert
                half NdotL = dot(normalWS, lightWS);
                half NdotLClamp = saturate(NdotL);
                //加一个偏移,模拟一下次表面散射
                half NdotLOffset = NdotL + _DiffuseOffset + layerFactor;
                half halfLambert = pow(saturate(NdotLOffset) * 0.5 + 0.5,2.0);
                half3 diffuseColor = lightColor * halfLambert;
                //计算菲尼尔反射
                half fresnel = pow((1.0 - saturate(dot(normalWS, viewWS))), _RimPower) * occlusion;
                half3 rimColor = _RimColor.rgb * fresnel;
                //计算各向异性高光
                half3 specularColor = LightingHair(bitangentWS,lightWS,normalWS,viewWS,_SpecularRange,_SpecularColor.rgb);
                specularColor = specularColor * _SpecularDensity * NdotLClamp * layerFactor;
                half3 finalColor =  albedo * (ambientColor + diffuseColor) * occlusion + rimColor + specularColor;

                half4 totalColor = half4(finalColor.rgb,alpha);
                return totalColor;
            }
            ENDHLSL
        }
    }
}
