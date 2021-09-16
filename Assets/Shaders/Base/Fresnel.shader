Shader "Lakehani/URP/Base/Fresnel"
{
    Properties
    {
        _Color("Color",Color) = (1,1,1,1)
        _Power("Power",Float) = 5
        [Toggle] _Reflection("Reflection",Float) = 1

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
            #pragma multi_compile __ _REFLECTION_ON 

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
                float3 normalWS : TEXCOORD0;
                float3 viewWS : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _Color;
            half _Power;
            CBUFFER_END


            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.normalWS =TransformObjectToWorldNormal(IN.normalOS);
                OUT.viewWS = GetWorldSpaceViewDir(positionWS);

                return OUT;
            }

            half Fresnel(half3 normal, half3 viewDir, half power)
            {
                //因为菲涅尔的计算公式有些复杂，所以用近似实现，常见一下2种
                //一般使用Schlick近似F0代表基础反射率,F0 = ((n-1)/(n+1))^2 n代表折射率1为空气
                //非金属的F0较小，金属F0较大，处于简化目的可以通过金属度在预设F0之间插值例如：float3 F0 = 0.04;F0 = lerp(F0 , BaseColor,Metallic);
                //后面PBR的例子中你会经常看到这个
                //F_Schlick(v, n) = F0 + (1 - F0)(1 - dot(v, n))^5
                //F_Schlick_UnrealEngine(H,V)= F0 + (1.0 - F0)* exp2((-5.55473 * HdotV - 6.98316) * HdotV);

                //F_Empricial(v, n) = max(0, min(1, bias + scale * (1- dot(v, n)^power)))


                //unity中常用这种方式实现 (1 - dot(v, n))^power
                return pow((1.0 - saturate(dot(normalize(normal), normalize(viewDir)))), power);
            }

            //为了看到反射内容，我直接采样了ReflectionProbe的Cube贴图
            half3 Reflection(float3 viewDirWS, float3 normalWS)
            {
                 float3 reflectVec = reflect(-viewDirWS, normalWS);
                 return DecodeHDREnvironment(SAMPLE_TEXTURECUBE(unity_SpecCube0, samplerunity_SpecCube0, reflectVec), unity_SpecCube0_HDR);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normalWS = normalize(IN.normalWS);
                half3 viewWS = SafeNormalize(IN.viewWS);
                half fresnel = Fresnel(normalWS, viewWS,_Power);
                half4 totlaColor = _Color* fresnel;
                //------- 这仅仅是演示菲涅尔和cubmap联合使用的例子，有镜面反射的感觉，基础的菲涅尔并不需要这个部分。
                #if defined(_REFLECTION_ON)
                    half3 cubemap=Reflection(viewWS,normalWS);
                    totlaColor.xyz *= cubemap;
                #endif
                //-------

                return totlaColor;
            }

            ENDHLSL
        }
    }
}
